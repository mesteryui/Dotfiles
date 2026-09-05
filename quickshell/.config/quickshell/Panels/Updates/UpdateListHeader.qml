import qs.Core
import qs.Panels.Updates.Content
import QtQuick

Item {
    id: root

    implicitHeight: 70

    // ── Background ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Qt.alpha(Appearance.md3.primary_container, 0.6)
    }

    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: 40
        z: 2
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.tint(Appearance.md3.surface, Qt.alpha(Appearance.md3.primary, 0.08)) }
        }
    }

    // ── Content ──────────────────────────────────────────────
    UpdateListHeaderContent {
        anchors.fill: parent
        z: 3
    }
}
