pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Bar
import qs.Core.Services as Services
import qs.Panels.Calendar
import QtQuick
import Quickshell

BarItem {
    id: wrapper

    clickable: true
    horizontalPadding: 12
    
    // Scale effect applied to the whole item instead of inner background
    scale: area.pressed ? 0.92 : (area.containsMouse ? 1.05 : 1.0)

    Behavior on scale { 
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad } 
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

        loading: wrapper.area.hoveredChanged || wrapper.area.pressed
        component: CalendarPopupWindow {
            id: popup

            anchorItem: wrapper
        }
    }
}