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
    }

    function send(cmd, key) {
        if (!socket.connected) {
            console.warn("[Hyprsunset] socket no conectado, ¿está corriendo el daemon?");
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

    Socket {
        id: socket

        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr/${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}/.hyprsunset.sock`

        onConnectionStateChanged: {
            root.available = connected;
            if (connected) {
                root._busy = false;
                root._pendingKey = "";
                root._queue = [];
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
            console.warn("[Hyprsunset] error de socket:", err);
            // Un connectToServer() fallido (daemon no corriendo todavía) no
            // siempre dispara onSocketDisconnected en Quickshell, así que
            // forzamos el ciclo connected=false -> true para que el próximo
            // tick de reconnectTimer pueda reintentar realmente.
            socket.connected = false;
        }

        parser: SplitParser {
            splitMarker: "" // las respuestas no siempre traen \n

            onRead: data => {
                const reply = data.trim();
                const key = root._pendingKey;
                root._busy = false;
                root._pendingKey = "";

                if (reply !== "") {
                    switch (key) {
                    case "identity":
                        root.identity = (reply === "true");
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
        }
    }

    // Reintento de conexión mientras el daemon no esté disponible.
    // socket.connected=true es idempotente si ya está conectado/conectando.
    Timer {
        id: reconnectTimer

        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!socket.connected)
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
            if (socket.connected && !root._busy && root._queue.length === 0)
                root.syncState();
        }
    }

    // --- Setters ---

    // Kelvin absoluto. hyprsunset clampea 1000-20000; lo replicamos para que
    // la UI (sliders, etc.) no mande valores que el daemon vaya a rechazar.
    // OJO: el daemon SIEMPRE fuerza identity=false al setear temperatura
    // explícitamente (ver IPCSocket.cpp), así que lo reflejamos optimistamente.
    function setTemperature(kelvin) {
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
        // `identity`; el "get" que sigue sí lleva key y confirma el valor
        // real que quedó aplicado en el daemon.
        send("identity false");
        send("identity get", "identity");
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
    }
}
