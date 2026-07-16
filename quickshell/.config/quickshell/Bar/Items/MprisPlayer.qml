pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Core.Services as Services
import qs.Panels.MediaPlayer
import qs.Bar.Content
import qs.Bar


Item {
    id: root
    implicitWidth: content.implicitWidth + 24
    implicitHeight: 30

    BarBackground {
        anchors.fill: parent
        active: titleInteraction.pressed
    }

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
        anchors.leftMargin: 12
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            const w = popupLoader.item
            if (w) w.visible = !w.visible
        }
    }


    // Helpers para no repetir la guardia null en cada binding
    LazyLoader {
        id: popupLoader
        loading: titleInteraction.pressed || titleInteraction.hoveredChanged
        component: MprisSubwindow {
            id: popup
            anchor.item: root
            anchor.margins.top: 20
            anchor.margins.bottom: 20
            anchor.edges: (Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom)
            anchor.gravity: (Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom)
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        }
    }
}
