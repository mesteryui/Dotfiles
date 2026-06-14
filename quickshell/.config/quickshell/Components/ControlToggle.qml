import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property bool active: false
    signal toggled

    implicitHeight: 64
    radius: 14
    color: active
        ? Colors.secondary_container
        : Colors.surface_variant

    Behavior on color { ColorAnimation { duration: 150 } }

    border.width: 1
    border.color: active
        ? Qt.alpha(Colors.primary, 0.5)
        : Colors.outline_variant

    Column {
        anchors.centerIn: parent
        spacing: 6

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            source: Quickshell.iconPath(root.iconName)
            width: 22; height: 22
            //color: root.active ? Colors.primary : Colors.on_surface_variant
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.pixelSize: 11
            color: root.active ? Colors.primary : Colors.on_surface_variant
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}