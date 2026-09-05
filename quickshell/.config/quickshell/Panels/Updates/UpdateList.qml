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
        anchors.fill: parent
    }

    // ── Content ──────────────────────────────────────────────
    UpdateListContent {
        id: listContent

        anchors.fill: parent
        onUpdateRequested: root.visible = false
    }
}
