pragma ComponentBehavior: Bound

import qs.Core.Services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// --- LockScreen ---
// Gestiona la ventana de bloqueo Wayland (WlSessionLock) y el IPC.
// La lógica de autenticación PAM vive en el singleton AuthService.

Scope {
    id: root

    property bool screenLocked: false

    // Se pone a true en cuanto la autenticación tiene éxito (o se fuerza un
    // unlock por IPC), y se propaga a cada LockScreenWrapper para que
    // reproduzca su animación de salida. WlSessionLockSurface no se puede
    // ocultar, solo destruir — por eso screenLocked no se pone a false hasta
    // que la animación termina (ver finishUnlock / onUnlockAnimationFinished).
    property bool isUnlocking: false

    // Nombre (ShellScreen.name) del monitor con foco justo antes de bloquear.
    // ShellScreen no expone ningún concepto de "primary", así que usamos el
    // monitor que realmente tenía el foco en Hyprland como noción de "pantalla
    // principal" de la lockscreen (reloj/MPRIS grandes, etc.) en vez del orden
    // arbitrario de Quickshell.screens.
    property string lockedMonitorName: ""

    function captureLockedMonitor() {
        root.lockedMonitorName = Hyprland.focusedMonitor?.name ?? "";
        root.screenLocked = true;
    }

    // Decide si una pantalla concreta es la "primaria" de esta sesión de bloqueo.
    // Fallback a Quickshell.screens[0] solo si no se pudo capturar el monitor
    // con foco (p. ej. Hyprland.focusedMonitor era null en ese instante).
    function isLockPrimary(screen) {
        if (!screen)
            return false;
        if (root.lockedMonitorName !== "")
            return screen.name === root.lockedMonitorName;
        return screen === (Quickshell.screens[0] ?? null);
    }

    // Llamado por cada LockScreenWrapper (uno por pantalla) al terminar su
    // animación de salida. Puede llegar varias veces (una por monitor); el
    // guard evita desbloquear dos veces.
    function finishUnlock() {
        if (!root.screenLocked)
            return;
        root.screenLocked = false;
        root.isUnlocking = false;
    }

    Connections {
        target: AuthService

        function onSuccessUnlocking() {
            root.isUnlocking = true;
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: root.screenLocked

        // WlSessionLock instancia este componente en cada pantalla automáticamente
        // (una vez por ShellScreen de Quickshell.screens) — no hace falta un
        // Variants/Scope manual por encima para el multi-monitor.
        surface: WlSessionLockSurface {
            id: lockSurface

            color: "transparent"

            LockScreenWrapper {
                anchors.fill: parent
                screen: lockSurface.screen
                isPrimary: root.isLockPrimary(lockSurface.screen)
                isUnlocking: root.isUnlocking

                onUnlockAnimationFinished: root.finishUnlock()
            }
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock() {
            root.captureLockedMonitor();
        }

        function unlock() {
            AuthService.abort();
            root.isUnlocking = true;
        }
    }
    //qmllint disable unresolved-type
    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"
        onPressed: {
            root.captureLockedMonitor();
        }
    }
}
