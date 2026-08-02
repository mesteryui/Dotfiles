pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Estado de Caps Lock ────────────────────────────────
    // Única fuente de verdad: refleja lo que reporta hyprctl.
    // NUNCA asignar esta propiedad desde fuera — usar
    // refreshCapsLock() para forzar una relectura real.
    property bool capsLockOn: false

    Component.onCompleted: refreshCapsLock()

    // Al pulsar Bloq Mayús, el estado del kernel tarda un
    // instante en reflejarse antes de que hyprctl lo reporte.
    // Se hace una consulta rápida y otra de confirmación algo
    // más tarde, por si la primera llega antes de que el driver
    // haya terminado de actualizar el estado real.
    Timer {
        id: debounce
        interval: 60
        onTriggered: {
            if (!capsLockProc.running)
                capsLockProc.running = true;
        }
    }

    Timer {
        id: confirmDebounce
        interval: 220
        onTriggered: {
            if (!capsLockProc.running)
                capsLockProc.running = true;
        }
    }

    function refreshCapsLock() {
        debounce.restart();
        confirmDebounce.restart();
    }

    Process {
        id: capsLockProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const kb = data.keyboards.find(k => k.main) ?? data.keyboards[0];
                    root.capsLockOn = kb?.capsLock ?? false;
                } catch (e) {
                    console.warn("No se pudo parsear hyprctl devices:", e);
                }
            }
        }
    }
}
