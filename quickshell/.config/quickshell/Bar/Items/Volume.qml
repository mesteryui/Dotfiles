import QtQuick
import Quickshell
import qs.Bar.Content
import qs.Core.Services as Services
import qs.Shared.Background

Item {
    id: root
    implicitWidth: content.implicitWidth + 20
    implicitHeight: 30
    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        enabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "wiremix"])
    }
    SurfaceBackground {
        anchors.fill: parent
        active: interaction.containsMouse
        scale: interaction.pressed ? 0.92: (interaction.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
    }

    VolumeContent {
        id: content
        anchors.centerIn: parent
        iconName: Services.AudioService.materialIcon
        text: Math.round(Services.AudioService.volume * 100) + "%"
    }
    
}