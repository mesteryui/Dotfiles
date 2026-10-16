pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Bar
import qs.Core
import qs.Core.Services as Services
import qs.Panels.Calendar
import QtQuick
import Quickshell

BarItem {
    id: wrapper

    clickable: true
    horizontalPadding: 12

    // Scale effect applied to the whole item instead of inner background
    scale: pressed ? 0.92 : (hovered ? 1.05 : 1.0)

    Behavior on scale {
        SpringAnimation {
            spring: Appearance.motion.springSnappy.spring
            damping: Appearance.motion.springSnappy.damping
            mass: Appearance.motion.springSnappy.mass
            epsilon: 0.005
        }
    }

    ClockContent {
        id: content

        anchors.centerIn: parent
    }

    onClicked: {
        const w = popupLoader.item;
        if (w)
            w.visible = !w.visible;
    }

    LazyLoader {
        id: popupLoader

        // `hovered` (bool), no `hoveredChanged` (señal, siempre truthy).
        loading: wrapper.hovered || wrapper.pressed
        component: CalendarPopupWindow {
            id: popup

            anchorItem: wrapper
        }
    }
}
