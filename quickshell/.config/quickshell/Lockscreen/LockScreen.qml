pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io
import qs.Core.Services

// --- LockScreen ---
// Gestiona la ventana de bloqueo Wayland (WlSessionLock) y el IPC.
// La lógica de autenticación PAM vive en el singleton AuthService.

Scope {
    id: root
    property bool screenLocked: false

    Connections {
        target: AuthService
        function onSuccessUnlocking() {
            root.screenLocked = false
        }
    }

    // Adaptación a múltiples monitores mediante Variants y Scope por pantalla
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: screenScope
            required property ShellScreen modelData
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.screenLocked

        // WlSessionLock instancia este componente en cada pantalla automáticamente
        surface: WlSessionLockSurface {
            id: lockSurface
            color: "transparent"

            LockScreenWrapper {
                anchors.fill: parent
                screen: lockSurface.screen
                isPrimary: lockSurface.screen === (Quickshell.screens[0] ?? null)
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock() {
            root.screenLocked = true
        }
        function unlock() {
            AuthService.abort()
            root.screenLocked = false
        }
    }
}
