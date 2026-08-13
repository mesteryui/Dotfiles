pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Core.Services
import Quickshell.Hyprland

PopupWindow {
    id: root
    color: "transparent"
    grabFocus: true
    visible: false
    property Item anchorItem: parent

    readonly property bool barAtBottom: ConfigService.configs.bar.position === "bottom"

    // ── Focus ─────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false);
        }
    }
    anchor {
        item: root.anchorItem
        margins {
            top: 38
            bottom: 38
        }
        adjustment: PopupAdjustment.ResizeY | PopupAdjustment.SlideX
        gravity: root.barAtBottom ? Edges.Top : Edges.Bottom
        edges: root.barAtBottom ? Edges.Top : Edges.Bottom
    }
}
