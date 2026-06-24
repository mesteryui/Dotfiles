import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Core
import qs.Primitives
import qs.Core.Services as Services

Item {
    id: root

    implicitWidth: 380
    implicitHeight: 500

    function formatTime(timestamp) {
        if (!timestamp) return "";
        const date = new Date(timestamp);
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${hours}:${minutes}`;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── Cabecera ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Notificaciones"
                font.family: Services.ConfigService.configs.appearence.fontSans
                font.pixelSize: 18
                font.weight: Font.Bold
                color: Appearance.md3.on_surface
                Layout.fillWidth: true
            }

            // Indicador de DND activo en cabecera
            Rectangle {
                visible: Services.NotificationService.dnd
                height: 20
                width: dndText.implicitWidth + 12
                radius: 10
                color: Qt.alpha(Appearance.md3.error, 0.15)
                border.width: 1
                border.color: Appearance.md3.error

                Text {
                    id: dndText
                    anchors.centerIn: parent
                    text: "DND Activo"
                    font.family: Services.ConfigService.configs.appearence.fontSans
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Appearance.md3.error
                }
            }
        }

        // ── Controles: DND y Limpiar Historial ─────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Toggle de No Molestar
            ControlToggle {
                Layout.fillWidth: true
                label: "No Molestar"
                iconName: Services.NotificationService.dnd ? "notifications_off" : "notifications"
                active: Services.NotificationService.dnd
                onToggled: Services.NotificationService.toggleDnd()
            }

            // Botón Limpiar Historial
            Rectangle {
                id: clearBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 14
                color: Appearance.md3.surface_variant
                border.width: 1
                border.color: Appearance.md3.outline_variant

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        icon: "delete_sweep"
                        size: 20
                        color: Appearance.md3.on_surface_variant
                    }

                    Text {
                        text: "Limpiar Todo"
                        font.family: Services.ConfigService.configs.appearence.fontSans
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Appearance.md3.on_surface_variant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: clearBtn.border.color = Appearance.md3.primary
                    onExited: clearBtn.border.color = Appearance.md3.outline_variant
                    onClicked: Services.NotificationService.clearHistory()
                }
            }
        }

        // Divisor
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.md3.outline_variant
            opacity: 0.3
        }

        // ── Lista de Notificaciones del Historial o Empty State ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Estado Vacío (Empty State)
            ColumnLayout {
                anchors.centerIn: parent
                visible: Services.NotificationService.history.length === 0
                spacing: 12

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: Services.NotificationService.dnd ? "notifications_paused" : "notifications"
                    size: 48
                    color: Appearance.md3.on_surface_variant
                    opacity: 0.35
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Services.NotificationService.dnd 
                        ? "Modo no molestar activo\nLas notificaciones se guardan aquí silenciosamente"
                        : "No tienes notificaciones pendientes"
                    font.family: Services.ConfigService.configs.appearence.fontSans
                    font.pixelSize: 12
                    color: Appearance.md3.on_surface_variant
                    opacity: 0.6
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.2
                }
            }

            // Historial con Scroll
            ListView {
                id: historyListView
                anchors.fill: parent
                model: Services.NotificationService.history
                spacing: 8
                visible: Services.NotificationService.history.length > 0
                clip: true

                // Efectos de transición para borrar items del historial
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 150
                        }
                        NumberAnimation {
                            property: "height"
                            to: 0
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Rectangle {
                    id: historyCard
                    width: historyListView.width
                    height: cardLayout.implicitHeight + 20
                    radius: 12
                    color: Appearance.md3.surface_container
                    border.width: 1
                    border.color: Appearance.md3.outline_variant
                    opacity: 1

                    RowLayout {
                        id: cardLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 10
                            topMargin: 10
                        }
                        spacing: 10

                        // Icono App o Genérico
                        IconImage {
                            source: modelData.appIcon !== ""
                                ? (modelData.appIcon.startsWith("/") ? "file://" + modelData.appIcon : modelData.appIcon)
                                : "dialog-information"
                            width: 28
                            height: 28
                            Layout.alignment: Qt.AlignTop
                        }

                        // Textos: App, Tiempo, Título, Cuerpo
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: modelData.appName !== "" ? modelData.appName : "Sistema"
                                    font.family: Services.ConfigService.configs.appearence.fontSans
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Appearance.md3.primary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.formatTime(modelData.time)
                                    font.family: Services.ConfigService.configs.appearence.fontSans
                                    font.pixelSize: 9
                                    color: Appearance.md3.on_surface_variant
                                    opacity: 0.7
                                }
                            }

                            Text {
                                text: modelData.summary
                                font.family: Services.ConfigService.configs.appearence.fontSans
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: Appearance.md3.on_surface
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                            }

                            Text {
                                text: modelData.body
                                font.family: Services.ConfigService.configs.appearence.fontSans
                                font.pixelSize: 11
                                color: Appearance.md3.on_surface_variant
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                            }
                        }

                        // Imagen Opcional Miniatura
                        ClippingRectangle {
                            width: 36
                            height: 36
                            radius: 6
                            visible: modelData.image !== ""
                            Layout.alignment: Qt.AlignTop

                            Image {
                                anchors.fill: parent
                                source: modelData.image !== ""
                                    ? (modelData.image.startsWith("/") ? "file://" + modelData.image : modelData.image)
                                    : ""
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        // Botón de Borrar
                        ButtonIcon {
                            iconName: "delete"
                            iconSize: 14
                            padding: 4
                            iconColor: Appearance.md3.on_surface_variant
                            opacity: 0.6
                            Layout.alignment: Qt.AlignTop
                            onClicked: Services.NotificationService.removeFromHistory(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
