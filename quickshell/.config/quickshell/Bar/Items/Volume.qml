import QtQuick
import Quickshell
import qs.Bar.Content
import qs.Core.Services as Services
import qs.Shared.Background

BarItem {
    id: root
    clickable: true
    horizontalPadding: 10
    
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "wiremix"])

    VolumeContent {
        id: content
        anchors.centerIn: parent
        iconName: Services.AudioService.materialIcon
        text: Math.round(Services.AudioService.volume * 100) + "%"
    }
}