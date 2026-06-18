import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Core
import qs.Core.Services as Services
import qs.Components

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Header del Centro de Notificaciones
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Notificaciones"
                font.pixelSize: 22
                font.weight: Font.Bold
                color: Colors.md3.on_surface
                Layout.fillWidth: true
            }

            // Toggle No Molestar (DND)
            RowLayout {
                spacing: 8
                Text {
                    text: "No molestar"
                    font.pixelSize: 12
                    color: Colors.md3.on_surface_variant
                }
                Switch {
                    checked: Services.NotificationService.dnd
                    onToggled: Services.NotificationService.dnd = checked
                }
            }
        }

        // Acciones globales
        RowLayout {
            Layout.fillWidth: true
            visible: Services.NotificationService.notifications.count > 0

            Button {
                text: "Limpiar todo"
                flat: true
                onClicked: Services.NotificationService.dismissAll()
                
                contentItem: Text {
                    text: parent.text
                    color: Colors.md3.primary
                    font.weight: Font.Medium
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "Marcar como leídas"
                flat: true
                onClicked: Services.NotificationService.markAllRead()
                
                contentItem: Text {
                    text: parent.text
                    color: Colors.md3.on_surface_variant
                    font.weight: Font.Medium
                }
            }
        }

        // Lista de notificaciones
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            model: Services.NotificationService.notifications
            
            delegate: NotificationItem {
                width: listView.width
                modelData: modelData
                
                // Efecto visual para no leídas
                opacity: Services.NotificationService.isRead(modelData.id) ? 0.7 : 1.0
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            // Placeholder cuando no hay nada
            Column {
                anchors.centerIn: parent
                visible: listView.count === 0
                spacing: 12
                
                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "notifications_off"
                    size: 48
                    color: Colors.md3.on_surface_variant
                    opacity: 0.3
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Todo al día"
                    color: Colors.md3.on_surface_variant
                    font.pixelSize: 16
                    opacity: 0.5
                }
            }
        }
    }
}
