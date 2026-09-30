// M3SelectionFill — fondo de selección M3 (list selected-state).
// selected=true => selectedFill (default secondary_container).
// selected=false => unselectedFill (default transparent).
// Lleva animación de color y z:-1 para ir detrás del contenido.
import qs.Core
import QtQuick

Rectangle {
    id: root

    property bool selected: false
    property color selectedFill: Appearance.md3.secondary_container
    property color unselectedFill: "transparent"

    color: selected ? selectedFill : unselectedFill
    z: -1

    Behavior on color {
        ColorAnimation {
            duration: Appearance.motion.short3
        }
    }
}
