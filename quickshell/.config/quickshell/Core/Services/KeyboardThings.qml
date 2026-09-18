pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    // ── Estado de Caps Lock ────────────────────────────────
    // Única fuente de verdad: refleja lo que reporta hyprctl.
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
    // instante en reflejarse antes de que hyprctl lo reporte.
    // Se hace una consulta rápida y otra de confirmación algo
    // más tarde, por si la primera llega antes de que el driver
    // haya terminado de actualizar el estado real.
    Timer {
        id: debounce

        interval: 60
        onTriggered: {
            if (!keyStateProc.running)
                keyStateProc.running = true;
        }
    }

    Timer {
        id: confirmDebounce

        interval: 220
        onTriggered: {
            if (!keyStateProc.running)
                keyStateProc.running = true;
        }
    }

    function refreshCapsLock() {
        debounce.restart();
        confirmDebounce.restart();
    }

    // Una sola llamada a `hyprctl -j devices` por refresco: del mismo JSON
    // salen capsLock (teclado principal) y numLock (numpad dedicado o
    // principal como fallback). Antes eran dos procesos con el mismo comando.
    Process {
        id: keyStateProc

        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const mainKb = data.keyboards.find(k => k.main) ?? data.keyboards[0];
                    root.capsLockOn = mainKb?.capsLock ?? false;
                    const numKb = data.keyboards.find(k => k.name === "asus_numpad") ?? data.keyboards[0];
                    root.numsLock = numKb?.numLock ?? false;
                } catch (e) {
                    console.warn("No se pudo parsear hyprctl devices:", e);
                }
            }
        }
    }
}
