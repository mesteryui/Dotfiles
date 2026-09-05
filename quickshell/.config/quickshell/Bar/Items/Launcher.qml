pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Core
import QtQuick
import Quickshell

BarItem {
    id: root

    clickable: true
    horizontalPadding: 15

    scale: area.pressed ? 0.92 : (area.containsMouse ? 1.05 : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutQuad
        }
    }

    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "dashboard", "toggle"])

    FluentIcon {
        id: content

        anchors.centerIn: parent
        icon: "cachyos-symbolic"
        implicitSize: Appearance.font.pixelSize.hugeass
        color: Appearance.md3.primary
    }
}
