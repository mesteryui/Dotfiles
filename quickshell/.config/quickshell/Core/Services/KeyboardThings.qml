pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // ── Estado de Bloq Mayús / Bloq Num ────────────────────
    // Hyprland lo reporta POR TECLADO (el modificador XKB "locked" de cada
    // dispositivo), no de forma global: el teclado que pulsa el usuario
    // puede no ser el principal (`main`). Por eso se guarda el estado de
    // cada dispositivo y se detecta cuál ha cambiado: ese es el del usuario
    // y su estado es el que se muestra en el OSD.
    // NUNCA asignar estas propiedades desde fuera — las rellena el
    // servicio al leer j/devices.
    property bool capsLockOn: false
    property bool numsLock: false

    // true cuando ya se leyó el estado real de los teclados al menos una vez.
    // Distingue la sincronización de arranque (que no debe pintar nada) de
    // un cambio real del usuario.
    // NUNCA asignar desde fuera: lo pone el servicio al leer j/devices.
    property bool synced: false

    // Estado por dispositivo (nombre -> bool). Vacío = aún no sincronizado.
    property var _capsByDevice: ({})
    property var _numByDevice: ({})

    // Teclado principal (Hyprland lo marca con main:true).
    property string _mainDevice: ""

    // Emitidos cuando la lectura confirma un cambio real del usuario. La UI
    // pinta el OSD con estos avisos: así sale siempre que el estado cambia
    // (aunque el kernel tarde en reflejar el LED) y nunca sale al arrancar.
    signal capsLockRefreshed(bool active)
    signal numLockRefreshed(bool active)

    // Lee el estado de todos los teclados por el socket IPC de Hyprland
    // (los mismos bytes que `hyprctl j/devices`, sin fork).
    // Las peticiones se encolan en HyprlandIpc: llamar dos veces seguidas es
    // seguro.
    function queryDevices() {
        HyprlandIpc.send("j/devices");
    }

    // El atajo global (quickshell:capsLock) es la vía rápida: al pulsar la
    // tecla se consulta el estado INMEDIATAMENTE. El compositor ya ha
    // aplicado el cambio cuando responde, así que el OSD sale en ~10 ms.
    function refreshCapsLock() {
        queryDevices();
    }

    // Teclados cuyo estado cambió entre dos lecturas. Un teclado nuevo
    // (undefined) no cuenta como cambio: no lo ha pulsado el usuario.
    function changedDevices(prev, now) {
        const changed = [];
        for (const name in now) {
            if (prev[name] === undefined)
                continue;
            if (prev[name] !== now[name])
                changed.push(name);
        }
        return changed;
    }

    // Aplica el estado recién leído. Si algún teclado ha cambiado, ese es
    // el que ha pulsado el usuario: su nuevo estado es el que se muestra.
    function applyStates(capsNow, numNow) {
        const first = !root.synced;
        const capsChanged = root.changedDevices(root._capsByDevice, capsNow);
        const numChanged = root.changedDevices(root._numByDevice, numNow);
        root._capsByDevice = capsNow;
        root._numByDevice = numNow;

        if (first) {
            // Sincronización de arranque: se guarda el estado pero no se
            // avisa (el OSD no debe saltar solo al iniciar la sesión).
            root.synced = true;
            if (root._mainDevice !== "") {
                root.capsLockOn = capsNow[root._mainDevice] === true;
                root.numsLock = numNow[root._mainDevice] === true;
            }
            return;
        }

        if (capsChanged.length > 0) {
            root.capsLockOn = capsNow[capsChanged[0]] === true;
            root.capsLockRefreshed(root.capsLockOn);
        }
        if (numChanged.length > 0) {
            root.numsLock = numNow[numChanged[0]] === true;
            root.numLockRefreshed(root.numsLock);
        }
    }

    Component.onCompleted: queryDevices()

    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "capsLock"
        description: "caps_lock"
        onPressed: {
            root.refreshCapsLock();
        }
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "numLock"
        description: "num_lock"
        onPressed: {
            root.refreshCapsLock();
        }
    }

    // Red de seguridad: el atajo global depende de que el compositor
    // entregue la tecla (permisos, keymap, atajo enlazado...). Si eso no
    // ocurre, el estado del teclado sigue cambiando y aquí se detecta: el
    // OSD sale como tarde 350 ms, pero sale. Es mucho más barato que el
    // sondeo continuo que había antes (60 ms + 220 ms en bucle).
    Timer {
        id: pollTimer

        interval: 350
        repeat: true
        running: true
        onTriggered: root.queryDevices()
    }

    Connections {
        target: HyprlandIpc
        ignoreUnknownSignals: true

        function onReplyReceived(command, reply) {
            if (command !== "j/devices")
                return;
            try {
                const data = JSON.parse(reply);
                const capsNow = {};
                const numNow = {};
                let mainName = "";
                for (const k of data.keyboards) {
                    capsNow[k.name] = k.capsLock === true;
                    numNow[k.name] = k.numLock === true;
                    if (k.main === true && mainName === "")
                        mainName = k.name;
                }
                root._mainDevice = mainName;
                root.applyStates(capsNow, numNow);
            } catch (e) {
                console.warn("No se pudo parsear devices de Hyprland:", e);
            }
        }

        function onRequestFailed(command, reason) {
            if (command !== "j/devices")
                return;
            console.warn("[KeyboardThings] j/devices falló:", reason);
        }
    }
}
