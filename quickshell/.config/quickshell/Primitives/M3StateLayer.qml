// M3StateLayer — velo de hover/pressed M3 sobre cualquier fondo.
// Uso: poner encima del contenido, debajo del MouseArea.
// La opacidad sale de Appearance.state (hovered 8%, pressed 12%).
import qs.Core
import QtQuick

Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    // Permite desactivar la animación durante swaps de modelo (ResultList).
    property bool animate: true
    // Sobre selección M3 el velo va en on_secondary_container, no en on_surface.
    property color tint: Appearance.md3.on_surface

    color: tint
    opacity: pressed ? Appearance.state.pressed : (hovered ? Appearance.state.hovered : 0)

    Behavior on opacity {
        enabled: root.animate
        NumberAnimation {
            duration: Appearance.motion.short2
        }
    }
}
