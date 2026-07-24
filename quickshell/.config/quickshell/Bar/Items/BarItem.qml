import QtQuick
import qs.Core

Rectangle {
    id: root

    property int horizontalPadding: 12
    property int verticalPadding: 0
    property color backgroundColor: Appearance.md3.surface_container_high
    property int itemRadius: Appearance.shape.normal

    property bool clickable: false
    signal clicked(variant mouse)
    property alias area: mouseArea

    // Necesitamos que los hijos se añadan al contenedor
    default property alias data: contentLoader.data

    // Usamos el tamaño del contenedor calculado por sus hijos
    implicitWidth: contentLoader.childrenRect.width + (horizontalPadding * 2)
    implicitHeight: 30

    radius: itemRadius
    color: clickable && mouseArea.containsMouse
    ? Qt.tint(backgroundColor, Qt.alpha(Appearance.md3.on_surface, 0.08))
    : backgroundColor

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Item {
        id: contentLoader
        anchors.centerIn: parent
        // Importante: No establecer width/height aquí para evitar bucles
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
