import QtQuick
import QtQuick.Layouts
import qs.Core

Rectangle {
    id: root

    property int horizontalPadding: 12
    property int verticalPadding: 0
    property color backgroundColor: Colors.md3.surface_container_high
    property int itemRadius: 20

    property bool clickable: false
    signal clicked(variant mouse)

    // Necesitamos que los hijos se añadan al contenedor
    default property alias data: contentLoader.data

    // Usamos el tamaño del contenedor calculado por sus hijos
    implicitWidth: contentLoader.childrenRect.width + (horizontalPadding * 2)
    implicitHeight: 30

    radius: itemRadius
    color: clickable && mouseArea.containsMouse
    ? Qt.tint(backgroundColor, Qt.alpha(Colors.md3.on_surface, 0.08))
    : backgroundColor

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    scale: clickable && mouseArea.pressed ? 0.92 : (clickable && mouseArea.containsMouse ? 1.05 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutQuad
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
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
