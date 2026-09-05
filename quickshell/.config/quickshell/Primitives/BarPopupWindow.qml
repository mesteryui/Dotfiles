pragma ComponentBehavior: Bound

import qs.Core.Services
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root

    property Item anchorItem: parent

    readonly property string _pos: ConfigService.configs.bar.position

    readonly property bool barAtBottom: _pos === "bottom"

    color: "transparent"
    grabFocus: true
    visible: false

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

        // Horizontal: el popup cae debajo o encima de la barra
        // Vertical:   el popup aparece al lado opuesto de la barra
        margins {
            top: barAtBottom ? 0 : 38
            bottom: barAtBottom ? 38 : 0
            left: 0
            right: 0
        }
        adjustment: PopupAdjustment.SlideX
        gravity: barAtBottom ? Edges.Top : Edges.Bottom
        edges: barAtBottom ? Edges.Top : Edges.Bottom
    }
}
