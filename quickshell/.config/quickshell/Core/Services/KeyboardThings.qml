pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // ── Estado de Caps Lock ────────────────────────────────
    // Única fuente de verdad: refleja lo que reporta Hyprland (`j/devices`).
    // NUNCA asignar esta propiedad desde fuera — usar
    // refreshCapsLock() para forzar una relectura real.
    property bool capsLockOn: false
    property bool numsLock: false

    function load() {
    }

    Component.onCompleted: refreshCapsLock()

    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "capsLock"
        description: "caps_lock"
        onPressed: {
            root.refreshCapsLock();
        }
    }

    // Al pulsar Bloq Mayús, el estado del kernel tarda un
    // instante en reflejarse antes de que Hyprland lo reporte.
    // Se hace una consulta rápida y otra de confirmación algo
    // más tarde, por si la primera llega antes de que el driver
    // haya terminado de actualizar el estado real.
    // Sin este retardo la lectura sale rancia y el OSD de
    // desactivado nunca se muestra (no hay cambio -> no hay señal).
    Timer {
        id: debounce

        interval: 60
        onTriggered: root.queryDevices()
    }

    Timer {
        id: confirmDebounce

        interval: 220
        onTriggered: root.queryDevices()
    }

    function refreshCapsLock() {
        debounce.restart();
        confirmDebounce.restart();
    }

    // Una sola llamada a `j/devices` por refresco: del mismo JSON
    // salen capsLock (teclado principal) y numLock (numpad dedicado o
    // principal como fallback). Antes eran dos procesos con el mismo comando;
    // ahora son los mismos bytes por el socket (HyprlandIpc), sin fork.
    // Las peticiones se encolan: llamar dos veces seguidas es seguro.
    function queryDevices() {
        HyprlandIpc.send("j/devices");
    }

    Connections {
        target: HyprlandIpc
        ignoreUnknownSignals: true

        function onReplyReceived(command, reply) {
            if (command !== "j/devices")
                return;
            try {
                const data = JSON.parse(reply);
                const mainKb = data.keyboards.find(k => k.main) ?? data.keyboards[0];
                root.capsLockOn = mainKb?.capsLock ?? false;
                const numKb = data.keyboards.find(k => k.name === "asus_numpad") ?? data.keyboards[0];
                root.numsLock = numKb?.numLock ?? false;
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
