pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "../Log.js" as Log

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

    // Event-driven: solo se consulta hyprctl al pulsar el atajo o al
    // arrancar. Sin polling ni timers: basta una lectura por pulsación.
    function refreshCapsLock() {
        if (!keyStateProc.running)
            keyStateProc.running = true;
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
                    Log.warn("No se pudo parsear hyprctl devices:", e);
                }
            }
        }
    }
}
