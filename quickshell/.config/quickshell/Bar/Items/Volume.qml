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
    }

    VolumeContent {
        id: content
        anchors.centerIn: parent
        iconName: Services.AudioService.materialIcon
        text: Math.round(Services.AudioService.volume * 100) + "%"
    }
    
}