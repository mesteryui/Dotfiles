import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Core
import qs.Core.Services as Services
import qs.Components

M3Card {
    id: root
    property var modelData
    readonly property var notif: modelData

    implicitWidth: 360
    
    content: Item {
        anchors.fill: parent
        anchors.margins: 12

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Icono o placeholder
                Rectangle {
                    width: 44
                    height: 44
                    radius: 10
                    color: Colors.md3.surface_container_highest
                    clip: true
                    
                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: {
                            if (!notif || !notif.appIcon) return "";
                            if (notif.appIcon.startsWith("/")) return "file://" + notif.appIcon;
                            return "image://icon/" + notif.appIcon;
                        }
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "notifications"
                        size: 24
                        visible: parent.children[0].status !== Image.Ready
                        color: Colors.md3.primary
                    }
                }

                // Cabecera y contenido de texto
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: notif ? (notif.appName || "Sistema") : ""
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Colors.md3.primary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: notif ? Qt.formatTime(new Date(Services.NotificationService.getTimestamp(notif.id)), "hh:mm") : ""
                            font.pixelSize: 10
                            color: Colors.md3.on_surface_variant
                            opacity: 0.7
                        }
                        
                        // Botón de cerrar
                        MouseArea {
                            width: 20; height: 20
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NotificationService.dismiss(notif)
                            
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "close"
                                size: 16
                                color: Colors.md3.on_surface_variant
                            }
                        }
                    }

                    Text {
                        text: notif ? notif.summary : ""
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Colors.md3.on_surface
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Cuerpo de la notificación
            Text {
                text: notif ? notif.body : ""
                font.pixelSize: 13
                color: Colors.md3.on_surface_variant
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 3
                Layout.fillWidth: true
                visible: text !== ""
            }

            // Acciones
            RowLayout {
                id: actionRow
                Layout.fillWidth: true
                spacing: 8
                visible: notif && notif.actions && notif.actions.length > 0

                Repeater {
                    model: notif ? notif.actions : []

                    delegate: Rectangle {
                        height: 28
                        implicitWidth: actionLabel.implicitWidth + 20
                        radius: 14
                        color: actionMouse.containsMouse ? Colors.md3.primary_container : Colors.md3.surface_container_highest
                        
                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: actionMouse.containsMouse ? Colors.md3.on_primary_container : Colors.md3.on_surface
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NotificationService.invokeAction(notif, modelData.id)
                        }
                    }
                }
            }
        }
    }
}
