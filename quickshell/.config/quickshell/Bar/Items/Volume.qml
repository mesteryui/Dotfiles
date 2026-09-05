import qs.Bar.Content
import qs.Core.Services as Services
import qs.Panels.Volume
import QtQuick

BarItem {
    id: root

    clickable: true
    horizontalPadding: 10

    onClicked: volumePanel.visible = !volumePanel.visible

    VolumePanel {
        id: volumePanel
    }

    VolumeContent {
        id: content

        anchors.centerIn: parent
        iconName: Services.AudioService.materialIcon
        text: Math.round(Services.AudioService.volume * 100) + "%"
    }
}
