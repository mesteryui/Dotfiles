pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// --- Hyprsunset ---
// Singleton que habla con el daemon `hyprsunset` por su Unix Socket
// ($XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock).
//
// Protocolo verificado contra el código fuente real de hyprwm/hyprsunset
// (src/IPCSocket.cpp), no contra la wiki (que solo documenta la config, no el IPC):
//
//   identity              -> fuerza identity=true (apaga el filtro), responde "ok"
//   identity get          -> responde "true" | "false"
//   identity true|false   -> setea identity, responde "ok"
//   temperature           -> responde el Kelvin actual (string numérico)
//   temperature <K>       -> setea Kelvin absoluto [1000-20000] y SIEMPRE pone identity=false
//   temperature +N | -N   -> ajuste relativo, clamp server-side [1000-20000]
//   gamma                 -> responde el % de gamma actual (string numérico)
//   gamma <pct>           -> setea gamma absoluto [0-maxGamma], NO toca identity
//   gamma +N | -N         -> ajuste relativo, clamp server-side
//   reset [temperature|gamma|identity]  -> recarga el perfil de config, responde "ok"
//   profile               -> texto multilínea con el perfil activo (no lo parseamos aquí)
//
// Detalle clave que el archivo original no manejaba: el daemon procesa los
// requests EN ORDEN sobre la misma conexión persistente (un accept() + loop de
// read/write), pero es un SOCK_STREAM sin delimitador de mensajes. Si se manda
// más de un comando sin esperar la respuesta del anterior, el daemon puede
// recibirlos concatenados en un solo read() y el parseo se rompe (por eso
// `syncState()` en la versión anterior era poco fiable). Aquí se resuelve con
// una cola FIFO que solo tiene un request "en vuelo" a la vez.
//
// Fuentes externas y propiedad del estado:
//   el socket lo puede escribir cualquiera (otro cliente, perfiles por hora
//   de hyprsunset.conf, timers de systemd con `qs ipc call night_light ...`):
//   gana el último escritor y este servicio converge leyendo (sync al
//   conectar + drift cada 30 s). Los comandos mutadores mandados sin conexión
//   no se pierden: se guardan en _offlineJournal y se reproducen en orden al
//   conectar, antes del sync.
Singleton {
    id: root

    // --- Estado espejo del daemon ---
    property int temperature: 6000        // Kelvin, default real de hyprsunset
    property real gammaPct: 100           // % de gamma, default real de hyprsunset
    property bool identity: true          // true = matriz identidad (sin filtro)
    property bool available: false        // ¿socket conectado?
    property bool syncing: false          // ¿hay un syncState() en curso?
    readonly property bool nightLightActive: available && !identity

    // Kelvin usado cuando activamos sin especificar temperatura (fallback si
    // todavía no sincronizamos nada con el daemon)
    property int lastKnownTemperature: 6000

    // --- Cola de comandos (1 in-flight a la vez) ---
    property var _queue: []
    property bool _busy: false
    property string _pendingKey: ""
    // Reensamblado de replies (el stream puede partirlas en trozos).
    property string _stash: ""
    // Comandos mutadores pedidos sin conexión, en orden (incluido `reset`).
    property var _offlineJournal: []
    // Anti-spam de warns por episodio de desconexión.
    property bool _offlineWarned: false
    // Backoff de reconexión: intentos desde la última conexión.
    property int _connectAttempts: 0

    function _enqueue(cmd, key) {
        _queue.push({
            cmd: cmd,
            key: key ?? ""
        });
        _pump();
    }

    function _pump() {
        if (_busy || _queue.length === 0 || !socket.connected)
            return;
        const next = _queue.shift();
        _busy = true;
        _pendingKey = next.key;
        socket.write(next.cmd);
        socket.flush();
        replyTimeout.restart();
    }

    function send(cmd, key) {
        if (!socket.connected) {
            // Sin conexión los mutadores (key vacía: sets, reset) se guardan
            // en orden para reproducirlos al conectar; los gets de
            // confirmación no importan (el sync posterior los cubre).
            if (!key) {
                if (root._offlineJournal.length > 50)
                    root._offlineJournal.shift();
                root._offlineJournal.push(cmd);
            }
            if (!root._offlineWarned) {
                root._offlineWarned = true;
                console.warn("[Hyprsunset] socket no conectado, comando guardado para al conectar:", cmd);
            }
            return;
        }
        _enqueue(cmd, key);
    }

    // --- Sincronización completa del estado ---
    function syncState() {
        syncing = true;
        _enqueue("identity get", "identity");
        _enqueue("temperature", "temperature");
        _enqueue("gamma", "gamma");
    }

    // Ruta como la construye el daemon (ver IPCSocket.cpp): sin
    // XDG_RUNTIME_DIR se usa /run/user/UID, y sin
    // HYPRLAND_INSTANCE_SIGNATURE el sock cuelga directo de USERDIR.
    readonly property string socketPath: {
        const his = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        const rt = Quickshell.env("XDG_RUNTIME_DIR");
        const uid = Quickshell.env("UID");
        const userDir = rt ? rt + "/hypr/" : (uid ? "/run/user/" + uid + "/hypr/" : "");
        if (userDir === "")
            return "";
        return his ? userDir + his + "/.hyprsunset.sock" : userDir + ".hyprsunset.sock";
    }

    Socket {
        id: socket

        path: root.socketPath

        onConnectionStateChanged: {
            root.available = connected;
            replySettle.stop();
            replyTimeout.stop();
            root._stash = "";
            if (connected) {
                root._busy = false;
                root._pendingKey = "";
                root._queue = [];
                root._connectAttempts = 0;
                reconnectTimer.interval = 2000;
                root._offlineWarned = false;
                // Reproduce en orden lo pedido sin conexión (incluido un
                // posible `reset`) y luego sincroniza para confirmar.
                for (let i = 0; i < root._offlineJournal.length; i++)
                    root._enqueue(root._offlineJournal[i], "");
                root._offlineJournal = [];
                Qt.callLater(root.syncState);
            } else {
                // conexión caída: limpiamos la cola, ya no tiene sentido
                // vaciarla contra un socket muerto. reconnectTimer se
                // encarga de reintentar.
                root._busy = false;
                root._pendingKey = "";
                root._queue = [];
                root.syncing = false;
            }
        }

        onError: err => {
            // Un connectToServer() fallido (daemon no corriendo todavía) no
            // siempre dispara onSocketDisconnected en Quickshell, así que
            // forzamos el ciclo connected=false -> true para que el próximo
            // tick de reconnectTimer pueda reintentar realmente.
            // Un aviso por episodio: si el daemon no existe, no spamea.
            if (!root._offlineWarned) {
                root._offlineWarned = true;
                console.warn("[Hyprsunset] error de socket:", err);
            }
            socket.connected = false;
        }

        parser: SplitParser {
            splitMarker: "" // las respuestas no siempre traen \n

            onRead: data => {
                // Reensamblado: el stream puede partir una respuesta en
                // varios trozos; se consume cuando lleva 30 ms quieta.
                root._stash += data;
                replySettle.restart();
            }
        }
    }

    // Una respuesta por ráfaga: el daemon escribe cada reply en un solo
    // write(), así que 30 ms de quietud = reply completa.
    Timer {
        id: replySettle

        interval: 30
        onTriggered: {
            const reply = root._stash;
            root._stash = "";
            root._consumeReply(reply);
        }
    }

    // Si una respuesta no llega, no se reintenta (un relativo se aplicaría
    // dos veces): se desbloquea y la confirmación/get que va detrás, o el
    // próximo sync, converge al valor real.
    Timer {
        id: replyTimeout

        interval: 2000
        onTriggered: {
            if (!root._busy)
                return;
            root._busy = false;
            root._pendingKey = "";
            if (root._queue.length === 0)
                root.syncing = false;
            root._pump();
        }
    }

    // Consume UNA reply ya reensamblada (ver replySettle).
    function _consumeReply(data) {
        replyTimeout.stop();
        const reply = data.trim();
        const key = root._pendingKey;
        root._busy = false;
        root._pendingKey = "";

        if (reply !== "") {
            switch (key) {
            case "identity":
                // Solo "true"/"false" valen: un error del daemon ("invalid
                // command", ...) no debe tumbar el estado a false.
                if (reply === "true")
                    root.identity = true;
                else if (reply === "false")
                    root.identity = false;
                break;
            case "temperature":
                if (!isNaN(Number(reply))) {
                    root.temperature = Math.round(Number(reply));
                    if (!root.identity)
                        root.lastKnownTemperature = root.temperature;
                }
                break;
            case "gamma":
                if (!isNaN(Number(reply)))
                    root.gammaPct = Math.round(Number(reply));
                break;
            // key === "" -> confirmaciones "ok" de comandos mutadores,
            // no requieren acción (ya aplicamos el estado optimista).
            }
        }

        if (key === "temperature" || key === "gamma" || key === "identity")
            root.syncing = _queue.length > 0;

        Qt.callLater(root._pump);
    }

    // Reintento de conexión mientras el daemon no esté disponible.
    // Backoff: intentos rápidos (~30 s) tras una caída para reconectar
    // enseguida; si nunca hubo daemon, tick lento para no spamear.
    Timer {
        id: reconnectTimer

        interval: 2000
        repeat: true
        running: root.socketPath !== "" && !socket.connected
        onTriggered: {
            if (socket.connected || root.socketPath === "")
                return;
            root._connectAttempts += 1;
            reconnectTimer.interval = root._connectAttempts < 15 ? 2000 : 30000;
            socket.connected = true;
        }
    }

    Component.onCompleted: socket.connected = true

    // --- Debounce para sliders (evita saturar la cola al arrastrar) ---
    property int _pendingTemperature: -1
    Timer {
        id: temperatureDebounce

        interval: 120
        onTriggered: {
            if (root._pendingTemperature >= 0) {
                // set "a ciegas" (sin key -> reply "ok", se ignora) seguido de
                // un get que confirma el valor REAL que el daemon aplicó
                // (puede clampear/redondear distinto a lo que pedimos).
                root.send(`temperature ${root._pendingTemperature}`);
                root.send("temperature", "temperature");
                root._pendingTemperature = -1;
            }
        }
    }

    property real _pendingGamma: -1
    Timer {
        id: gammaDebounce

        interval: 120
        onTriggered: {
            if (root._pendingGamma >= 0) {
                root.send(`gamma ${root._pendingGamma}`);
                root.send("gamma", "gamma");
                root._pendingGamma = -1;
            }
        }
    }

    // Red de seguridad: hyprsunset puede cambiar temperatura/gamma/identity
    // por su cuenta si hay perfiles con horario en hyprsunset.conf (el daemon
    // no empuja notificaciones a los clientes del socket, así que sin esto
    // el estado de la UI puede quedar desactualizado silenciosamente durante
    // horas). No corre mientras hay una sync o un comando en vuelo para no
    // pisarlos.
    Timer {
        id: driftGuardTimer

        interval: 30000
        repeat: true
        running: root.available
        onTriggered: {
            if (socket.connected && !root.syncing && !root._busy && root._queue.length === 0)
                root.syncState();
        }
    }

    // --- Setters ---

    // Kelvin absoluto. hyprsunset clampea 1000-20000; lo replicamos para que
    // la UI (sliders, etc.) no mande valores que el daemon vaya a rechazar.
    // OJO: el daemon SIEMPRE fuerza identity=false al setear temperatura
    // explícitamente (ver IPCSocket.cpp), así que lo reflejamos optimistamente.
    function setTemperature(kelvin) {
        if (!isFinite(kelvin))
            return;
        const clamped = Math.max(1000, Math.min(20000, Math.round(kelvin)));
        temperature = clamped;
        lastKnownTemperature = clamped;
        identity = false;
        _pendingTemperature = clamped;
        temperatureDebounce.restart();
    }

    // Ajuste relativo (usa el comando nativo `temperature +N`/`-N` en vez de
    // calcular el clamp client-side, así el server es la fuente de verdad).
    function adjustTemperature(deltaKelvin) {
        identity = false;
        const cmd = deltaKelvin >= 0 ? `temperature +${deltaKelvin}` : `temperature -${Math.abs(deltaKelvin)}`;
        send(cmd); // set, sin key -> reply "ok" se ignora
        send("temperature", "temperature"); // confirma el valor real post-clamp
    }

    // Gamma en % (0-100 típico, hasta `gamma_max` si el daemon fue lanzado
    // con --gamma_max > 100). No tocamos `identity`: gamma es independiente.
    function setGamma(percent) {
        if (!isFinite(percent))
            return;
        const clamped = Math.max(0, percent);
        gammaPct = clamped;
        _pendingGamma = clamped;
        gammaDebounce.restart();
    }

    function adjustGamma(deltaPercent) {
        const cmd = deltaPercent >= 0 ? `gamma +${deltaPercent}` : `gamma -${Math.abs(deltaPercent)}`;
        send(cmd); // set, sin key -> reply "ok" se ignora
        send("gamma", "gamma"); // confirma el valor real post-clamp
    }

    // --- Activación / desactivación / toggle coherentes con hyprsunset ---
    // "activate" = identity false (prende el filtro con el Kelvin/gamma que
    // el daemon ya tenga aplicado o el último conocido, NO un valor fijo
    // hardcodeado). "deactivate" = identity true (matriz identidad, sin
    // filtro). Esto es exactamente la semántica de `identity` en hyprsunset.
    function activate(kelvin) {
        if (kelvin !== undefined) {
            setTemperature(kelvin); // ya deja identity=false
            return;
        }
        identity = false;
        // el "set" NO lleva key -> su reply ("ok") se ignora sin tocar
        // `identity`; los "get" que siguen sí llevan key y confirman los
        // valores reales que quedaron aplicados en el daemon (la temperatura
        // también: pudo cambiar externamente con el filtro apagado).
        send("identity false");
        send("identity get", "identity");
        send("temperature", "temperature");
    }

    function deactivate() {
        identity = true;
        send("identity true");
        send("identity get", "identity");
    }

    function toggleNightLight() {
        if (nightLightActive)
            deactivate();
        else
            activate();
    }

    // Recarga el perfil activo desde la config de hyprsunset (hyprsunset.conf)
    // y luego re-sincroniza temperatura/gamma/identity reales.
    function resetToProfile() {
        send("reset");
        Qt.callLater(syncState);
    }

    // Foto del estado para scripts y automatización externa:
    // `qs ipc call night_light status`
    // -> {"temperature":6000,"gamma":100,"identity":true,"active":false,"available":true}
    function statusSnapshot(): string {
        return JSON.stringify({
            temperature: temperature,
            gamma: gammaPct,
            identity: identity,
            active: nightLightActive,
            available: available
        });
    }

    IpcHandler {
        target: "night_light"

        function activate() {
            root.activate();
        }

        function deactivate() {
            root.deactivate();
        }

        function toggle() {
            root.toggleNightLight();
        }

        function setTemperature(temp: int) {
            root.setTemperature(temp);
        }

        function setGamma(pct: real) {
            root.setGamma(pct);
        }

        function reset() {
            root.resetToProfile();
        }

        function status(): string {
            return root.statusSnapshot();
        }
    }
}
