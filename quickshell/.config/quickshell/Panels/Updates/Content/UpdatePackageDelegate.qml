import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

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
            leftMargin: Appearance.spacing.s
            rightMargin: Appearance.spacing.s
        }
        radius: Appearance.shape.verysmall
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Appearance.md3.primary
            opacity: delegateHover.hovered ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.motion.short3
                }
            }
        }
    }

    // ── Content ──────────────────────────────────────────────
    RowLayout {
        anchors {
            fill: parent
            leftMargin: Appearance.spacing.l
            rightMargin: Appearance.spacing.l
        }
        spacing: Appearance.spacing.s

        StyledText {
            Layout.fillWidth: true
            text: root.packageName
            font.pixelSize: Appearance.typeScale.bodySmall
            font.family: Services.ConfigService.configs.appearance.fontSans
            color: Appearance.md3.on_surface
            elide: Text.ElideRight
        }

        StyledText {
            Layout.maximumWidth: 60
            Layout.minimumWidth: 0
            text: root.oldVersion
            font.pixelSize: Appearance.typeScale.labelSmall
            font.family: Services.ConfigService.configs.appearance.monospace
            color: Appearance.md3.on_surface_variant
            opacity: Appearance.opacity.hint
            elide: Text.ElideMiddle
        }

        MaterialIcon {
            icon: "arrow_forward"
            size: 12
            color: Appearance.md3.primary
        }

        StyledText {
            Layout.maximumWidth: 60
            Layout.minimumWidth: 0
            text: root.newVersion
            font.pixelSize: Appearance.typeScale.labelSmall
            font.family: Services.ConfigService.configs.appearance.monospace
            color: Appearance.md3.primary
            elide: Text.ElideMiddle
        }
    }

    HoverHandler {
        id: delegateHover
    }
}
