pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Features.Notifications
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Contenido del popup de notificaciones anclado a la barra.
// Versión compacta del NotificationCenter: cabecera con DND + limpiar,
// lista scrolleable con las tarjetas de historial y estado vacío.
ColumnLayout {
    id: root

    property int count: Services.NotificationService.history ? Services.NotificationService.history.count : 0

    spacing: 10
    implicitWidth: 348

    // ── Cabecera ──────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.s

        StyledText {
            Layout.fillWidth: true
            text: Services.I18nService.getTranslation("notifications.title", "Notificaciones")
            color: Appearance.md3.on_surface
            font.family: Appearance.font.sans
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Medium
        }

        // Contador
        Rectangle {
            visible: root.count > 0
            implicitWidth: countLabel.implicitWidth + 16
            implicitHeight: 26
            radius: Appearance.shape.full
            color: Appearance.md3.primary_container

            StyledText {
                id: countLabel

                anchors.centerIn: parent
                text: root.count
                color: Appearance.md3.on_primary_container
                font.pixelSize: Appearance.typeScale.labelMedium
                font.bold: true
            }
        }

        // DND
        Rectangle {
            id: dndButton

            implicitWidth: 36
            implicitHeight: 36
            radius: Appearance.shape.full
            color: Services.NotificationService.dnd ? Appearance.md3.secondary_container : Appearance.md3.surface_container_high

            Accessible.role: Accessible.Button
            Accessible.checkable: true
            Accessible.checked: Services.NotificationService.dnd
            Accessible.name: Services.I18nService.getTranslation("notifications.dnd", "No molestar")

            MaterialIcon {
                anchors.centerIn: parent
                icon: Services.NotificationService.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                size: Appearance.font.pixelSize.large
                color: Services.NotificationService.dnd ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.NotificationService.toggleDnd()
            }
        }

        // Limpiar todo
        Rectangle {
            id: clearButton

            visible: root.count > 0
            implicitWidth: clearRow.implicitWidth + 20
            implicitHeight: 36
            radius: Appearance.shape.full
            color: Appearance.md3.secondary_container

            Accessible.role: Accessible.Button
            Accessible.name: Services.I18nService.getTranslation("notifications.clear_all", "Limpiar todo")

            RowLayout {
                id: clearRow

                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    icon: "delete_sweep"
                    size: Appearance.typeScale.bodyLarge
                    color: Appearance.md3.on_secondary_container
                }

                StyledText {
                    text: Services.I18nService.getTranslation("notifications.clear_all", "Limpiar todo")
                    font.pixelSize: Appearance.typeScale.labelMedium
                    font.bold: true
                    color: Appearance.md3.on_secondary_container
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.NotificationService.history.clear()
            }
        }
    }

    // ── Separador ─────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        visible: root.count > 0
        color: Appearance.md3.outline_variant
        opacity: 0.5
    }

    // ── Lista ─────────────────────────────────────────────────
    ListView {
        id: historyList

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 340)
        visible: root.count > 0
        clip: true
        spacing: Appearance.spacing.s
        boundsBehavior: Flickable.StopAtBounds
        model: Services.NotificationService.history

        ScrollBar.vertical: StyledScrollBar {}

        delegate: NotificationHistoryCard {
            width: historyList.width
            onRemoveRequested: Services.NotificationService.removeFromHistory(historyId)
        }
    }

    // ── Estado vacío ──────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 12
        visible: root.count === 0
        spacing: Appearance.spacing.s

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "notifications_none"
            size: 32
            color: Appearance.md3.on_surface_variant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Services.I18nService.getTranslation("notifications.empty_subtitle", "Sin notificaciones")
            color: Appearance.md3.on_surface_variant
            font.pixelSize: Appearance.typeScale.labelMedium
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
