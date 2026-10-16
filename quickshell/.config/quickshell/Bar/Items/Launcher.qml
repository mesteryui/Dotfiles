pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Core
import qs.Core.Services
import QtQuick
import Quickshell

BarItem {
    id: root

    clickable: true
    horizontalPadding: 15

    scale: pressed ? 0.92 : (hovered ? 1.05 : 1.0)

    Behavior on scale {
        SpringAnimation {
            spring: Appearance.motion.springSnappy.spring
            damping: Appearance.motion.springSnappy.damping
            mass: Appearance.motion.springSnappy.mass
            epsilon: 0.005
        }
    }

    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "dashboard", "toggle"])

    FluentIcon {
        id: content

        anchors.centerIn: parent
        icon: DistroService.icon
        implicitSize: Appearance.font.pixelSize.hugeass
        color: Appearance.md3.primary
    }
}
