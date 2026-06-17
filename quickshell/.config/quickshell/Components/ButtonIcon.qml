import Quickshell
import QtQuick
import "../Core"
import "."

Item {
    id: root

    required property string iconName
    signal clicked
    property int iconSize: 16
    property color iconColor: Colors.md3.on_surface

    implicitWidth: iconSize
    implicitHeight: iconSize

    opacity: enabled ? 1.0 : 0.38
    Behavior on opacity { NumberAnimation { duration: 150 } }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.iconName
        size: root.iconSize
        color: root.iconColor
        //font.family: "Material Symbols Rounded"
    }

    scale: mouse.pressed ? 1.20 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
