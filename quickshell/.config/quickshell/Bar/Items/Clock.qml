pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Core
import qs.Panels.Calendar
import QtQuick

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

    onClicked: popupLoader.toggle()

    BarPopup {
        id: popupLoader

        anchorItem: wrapper
        hovered: wrapper.hovered
        pressed: wrapper.pressed
        component: CalendarPopupWindow {
            id: popup
        }
    }
}
