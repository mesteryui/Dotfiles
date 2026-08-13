import QtQuick
import qs.Shared.Background
import qs.Panels.Updates.Content
import qs.Primitives

BarPopupWindow {
    id: root
    
    implicitWidth: 300
    implicitHeight: Math.min(500, listContent.implicitHeight)

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
