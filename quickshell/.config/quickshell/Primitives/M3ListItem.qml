// M3ListItem — fila seleccionable M3.
// Junta M3SelectionFill + M3StateLayer + MouseArea con la regla de
// contraste del proyecto:
//   seleccionado => contenido a on_secondary_container
//   no seleccionado => iconos a primary, textos a on_surface/variant
// (los colores de contenido los pone cada uso; aquí solo fondo + velo).
// Para delegates con lógica rara de hover (ResultList) usar
// M3SelectionFill + M3StateLayer sueltos en vez de este item.
import qs.Core
import QtQuick

Rectangle {
    id: root

    property bool selected: false
    property color selectedFill: Appearance.md3.secondary_container
    property color unselectedFill: "transparent"
    property bool hoverEnabled: true
    // Accesibilidad coherente (quickshell expone Attached.Accessible):
    // cada uso pone nombre (+ rol si no es un botón).
    property int accessibleRole: Accessible.Button
    property string accessibleName: ""

    Accessible.role: accessibleRole
    Accessible.name: accessibleName

    default property alias content: _inner.data

    signal clicked(var mouse)
    signal entered
    signal exited
    signal pressed(var mouse)
    signal released(var mouse)

    readonly property bool containsMouse: _mouse.containsMouse
    readonly property bool mousePressed: _mouse.pressed

    color: "transparent"

    M3SelectionFill {
        anchors.fill: parent
        radius: parent.radius
        selected: root.selected
        selectedFill: root.selectedFill
        unselectedFill: root.unselectedFill
    }

    M3StateLayer {
        anchors.fill: parent
        radius: parent.radius
        tint: root.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
        hovered: root.hoverEnabled && _mouse.containsMouse
        pressed: _mouse.pressed
    }

    Item {
        id: _inner

        anchors.fill: parent
    }

    MouseArea {
        id: _mouse

        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onEntered: root.entered()
        onExited: root.exited()
        onPressed: mouse => root.pressed(mouse)
        onReleased: mouse => root.released(mouse)
    }
}
