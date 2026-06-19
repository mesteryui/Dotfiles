import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Core.Services as Services
import qs.Core
import qs.Features.Subwindows
import qs.Components
import qs.Bar.Content
import qs.Bar
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: content.implicitWidth + 24
    implicitHeight: 30
    BarBackground {
        anchors.fill: parent
        highlighted: titleInteraction.containsMouse
        active: titleInteraction.pressed
        border.width: highlighted ? 1 : 0
        border.color: Colors.md3.primary
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    PlayerContent {
        id: content 
        anchors.centerIn: parent
        isHovered: titleInteraction.containsMouse
    }

    MouseArea {
        id: titleInteraction
        width: 150
        height: parent.height
        anchors.left: parent.left
        anchors.leftMargin: 12
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const w = popupLoader.item
            if (w) w.visible = !w.visible
        }
    }


    // Helpers para no repetir la guardia null en cada binding
    LazyLoader {
        id: popupLoader
        loading: true
        MprisSubwindow {
            id: popup
            anchor.item: root
            anchor.margins.top: 20
            anchor.margins.bottom: 20
            anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom)
            anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom)
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        }
    }


}
