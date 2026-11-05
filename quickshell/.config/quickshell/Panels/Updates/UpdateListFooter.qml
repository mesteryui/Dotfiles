import qs.Core
import qs.Panels.Updates.Content
import QtQuick

Item {
    id: root

    signal updateRequested

    implicitHeight: 64

    // ── Background ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Appearance.md3.surface_variant, 0.3)
        radius: Appearance.shape.card
    }

    // ── Content ──────────────────────────────────────────────
    UpdateFooterContent {
        anchors.fill: parent
        onUpdateRequested: root.updateRequested()
    }
}
