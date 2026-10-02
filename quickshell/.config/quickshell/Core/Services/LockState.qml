pragma Singleton

// Estado de bloqueo de sesión, espejo escribible de LockScreen.
// Existe para que cualquiera (p. ej. un proveedor de fondos) reaccione
// al bloqueo sin acoplarse al componente visual del lockscreen.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool locked: false
}
