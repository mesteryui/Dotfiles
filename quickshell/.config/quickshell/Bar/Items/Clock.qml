pragma ComponentBehavior: Bound
import qs.Bar.Content
import qs.Bar
import qs.Core.Services as Services
import QtQuick
import Quickshell
import qs.Panels.Calendar
MouseArea {
    id: wrapper
    implicitWidth: content.implicitWidth + 24
    implicitHeight: 30
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    BarBackground {
        anchors.fill: parent
        active: wrapper.containsMouse
        scale: wrapper.pressed ? 0.92: (wrapper.containsMouse ? 1.05 : 1.0)
        Behavior on scale { 
            NumberAnimation { duration: 100; easing.type: Easing.OutQuad } 
        }
    }
    ClockContent {
        id: content
        anchors.centerIn: parent
    }

    onClicked: {
        const w = popupLoader.item
        if (w) w.visible = !w.visible
    }
    
    LazyLoader {
        id: popupLoader
        loading: wrapper.hoveredChanged || wrapper.pressed
        component: CalendarPopupWindow {
            id: popup
            anchor.item: wrapper
            anchor.margins.top: 20
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
            anchor.margins.bottom: 20
            anchor.edges: Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom
            anchor.gravity: anchor.edges
        }
    }
}