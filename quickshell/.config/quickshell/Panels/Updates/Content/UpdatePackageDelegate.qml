import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services as Services
import qs.Primitives

// Fila de un paquete pendiente de actualización.
Item {
    id: root
    height: 44

    required property string packageName
    required property string oldVersion
    required property string newVersion

    // ── Background + state layer ─────────────────────────────
    Rectangle {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
        }
        radius: 8
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Appearance.md3.primary
            opacity: delegateHover.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // ── Content ──────────────────────────────────────────────
    RowLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: root.packageName
            font.pixelSize: 13
            font.family: Services.ConfigService.configs.appearence.fontSans
            color: Appearance.md3.on_surface
            elide: Text.ElideRight
        }

        StyledText {
            text: root.oldVersion
            font.pixelSize: 11
            font.family: Services.ConfigService.configs.appearence.monospace
            color: Appearance.md3.on_surface_variant
            opacity: 0.7
            elide: Text.ElideRight
        }

        MaterialIcon {
            icon: "arrow_forward"
            size: 12
            color: Appearance.md3.primary
        }

        StyledText {
            text: root.newVersion
            font.pixelSize: 11
            font.family: Services.ConfigService.configs.appearence.monospace
            color: Appearance.md3.primary
            elide: Text.ElideRight
        }
    }

    HoverHandler { id: delegateHover }
}
