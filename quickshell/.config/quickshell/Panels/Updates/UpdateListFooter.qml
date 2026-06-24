import QtQuick
import qs.Core
import qs.Panels.Updates.Content

Item {
    id: root
    implicitHeight: 64

    signal updateRequested()

    // ── Background ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Appearance.md3.surface_variant, 0.3)
    }

    // ── Content ──────────────────────────────────────────────
    UpdateFooterContent {
        anchors.fill: parent
        onUpdateRequested: root.updateRequested()
    }
}
