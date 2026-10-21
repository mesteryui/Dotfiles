pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Panels.MediaPlayer
import qs.Bar.Content
import qs.Shared.Background
import QtQuick

Item {
    id: root

    implicitWidth: content.implicitWidth + 24
    implicitHeight: 30

    SurfaceBackground {
        anchors.fill: parent
        active: titleInteraction.pressed
    }

    //visible: Services.MprisService.players.length > 0

    PlayerContent {
        id: content

        anchors.centerIn: parent
        isHovered: titleInteraction.containsMouse
    }

    MouseArea {
        id: titleInteraction

        enabled: Services.MprisService.activePlayer !== null
        width: content.width / 2
        height: parent.height
        anchors.left: parent.left
        anchors.leftMargin: Appearance.spacing.medium
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: popupLoader.toggle()
    }

    // Helpers para no repetir la guardia null en cada binding
    BarPopup {
        id: popupLoader

        anchorItem: root
        hovered: titleInteraction.containsMouse
        pressed: titleInteraction.pressed
        component: MprisSubwindow {
            id: popup
        }
    }
}
