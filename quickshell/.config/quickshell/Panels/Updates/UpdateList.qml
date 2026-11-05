import qs.Core
import qs.Shared.Background
import qs.Panels.Updates.Content
import qs.Primitives
import qs.Core.Services
import QtQuick

BarPopupWindow {
    id: root

    implicitWidth: 300
    implicitHeight: Math.min(500, listContent.implicitHeight)

    Shortcut {
        sequence: "U"
        onActivated: {
            UpdatesTracking.update();
            root.visible = false;
        }
    }
    Shortcut {
        sequence: "R"
        onActivated: UpdatesTracking.checkNow()
    }

    // ── Background ───────────────────────────────────────────
    PopupBackground {
        id: bg

        anchors.fill: parent
        surfaceRadius: Appearance.shape.card
        baseColor: Appearance.md3.surface
        showBorder: true
    }

    // ── Content ──────────────────────────────────────────────
    // Llena bg (con clip y radius), no el padre directo, y no renderiza
    // bordes propios.
    UpdateListContent {
        id: listContent

        anchors.fill: bg
        onUpdateRequested: root.visible = false
    }
}
