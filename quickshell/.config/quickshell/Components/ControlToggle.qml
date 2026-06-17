import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Core"
import "."

Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property bool active: false
    signal toggled

    implicitHeight: 64
    radius: 14
    color: active
        ? Colors.md3.secondary_container
        : Colors.md3.surface_variant

    Behavior on color { ColorAnimation { duration: 150 } }

    border.width: 1
    border.color: active
        ? Qt.alpha(Colors.md3.primary, 0.5)
        : Colors.md3.outline_variant

    Column {
        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.iconName
            size: 22
            color: root.active ? Colors.md3.primary : Colors.md3.on_surface_variant
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.pixelSize: 11
            color: root.active ? Colors.md3.primary : Colors.md3.on_surface_variant
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}