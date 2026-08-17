pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.Shared.Background
import qs.Primitives
import qs.Core

Item {
    id: root
    implicitWidth: content.childrenRect.width + 49
    implicitHeight: 30
    
    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "dashboard", "toggle"])
        enabled: true
    }

    SurfaceBackground {
        id: background
        anchors.fill: parent
        active: interaction.containsMouse
        scale: interaction.pressed ? 0.92: (interaction.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
    }

    /*MaterialIcon {
        id: content
        icon: "rocket_launch"
        size: Appearance.font.pixelSize.larger
        color: Appearance.md3.on_surface
        anchors.centerIn: parent
    }*/
    FluentIcon {
        id: content
        anchors.centerIn: parent
        icon: "cachyos-symbolic"
        implicitSize: Appearance.font.pixelSize.hugeass
        color: Appearance.md3.primary
    }
}
