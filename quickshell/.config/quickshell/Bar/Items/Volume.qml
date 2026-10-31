import qs.Bar.Content
import qs.Core.Services as Services
import qs.Panels.Volume
import QtQuick

BarItem {
    id: root

    clickable: true
    horizontalPadding: 10

    onClicked: volumePanel.toggle()

    BarPopup {
        id: volumePanel

        anchorItem: root
        hovered: root.hovered
        pressed: root.pressed
        component: VolumePanel {
            id: panel
        }
    }

    VolumeContent {
        id: content

        anchors.centerIn: parent
        icon: Services.AudioService.materialIcon
        text: Math.round(Services.AudioService.volume * 100) + "%"
    }
}
