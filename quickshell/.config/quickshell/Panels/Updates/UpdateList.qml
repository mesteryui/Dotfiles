import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Shared.Background
import qs.Panels.Updates.Content

PopupWindow {
    id: root
    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 300
    implicitHeight: Math.min(500, listContent.implicitHeight)

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    // ── Background ───────────────────────────────────────────
    PopupBackground {
        anchors.fill: parent
    }

    // ── Content ──────────────────────────────────────────────
    UpdateListContent {
        id: listContent
        anchors.fill: parent
        onUpdateRequested: root.visible = false
    }
}
