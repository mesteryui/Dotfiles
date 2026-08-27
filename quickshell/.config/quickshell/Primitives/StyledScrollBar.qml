import QtQuick
import QtQuick.Controls
import qs.Core

ScrollBar {
    id: root
    policy: ScrollBar.AsNeeded
    active: hovered || pressed
    contentItem: Rectangle {
        color: Appearance.md3.on_surface_variant
        implicitWidth: 4
        implicitHeight: root.visualSize
        radius: width / 2
        opacity: root.policy === ScrollBar.AlwaysOn || (root.active && root.size < 1.0) ? 0.5 : 0
    }
}
