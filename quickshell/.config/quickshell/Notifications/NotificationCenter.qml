// --- NotificationCenter ---
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.Core
import qs.Core.Services as Services
import qs.Components

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { top: true; right: true; bottom: true }
    implicitWidth: 420
    implicitHeight: 0

    visible: false

    readonly property var safeHistory: {
        const h = Services.NotificationService.history
        return Array.isArray(h) ? h : []
    }

    readonly property int activeCount: Services.NotificationService.notifications.length ?? 0
    readonly property int totalCount: activeCount + safeHistory.length

    function toggle() { visible = !visible }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    IpcHandler {
        target: "ui.notifications"
        function toggleNotificationCenter(): void { root.toggle() }
    }

    // ── Sombra ────────────────────────────────────────────────────────────
    Rectangle {
        id: shadowBacking
        anchors.fill: panel
        radius: panel.radius
    }

    MultiEffect {
        source: shadowBacking
        anchors.fill: shadowBacking
        shadowEnabled: true
        shadowColor: Colors.md3.shadow
        shadowOpacity: 0.22
        shadowBlur: 0.9
        shadowHorizontalOffset: -4
        shadowVerticalOffset: 0
    }

    // ── Panel ─────────────────────────────────────────────────────────────
    Rectangle {
        id: panel

        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
            margins: 12
        }
        width: 380
        radius: 28
        color: Colors.md3.surface_container_high

        // FIX: Behavior on transform no funciona — animar Translate directamente
        transform: Translate {
            id: slideTranslate
            x: root.visible ? 0 : 420
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Services.I18nService.getTranslation("notifications.title")
                    color: Colors.md3.on_surface
                    font.bold: true
                    font.pixelSize: 16
                    font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                }

                // FIX: contador real de notificaciones
                Rectangle {
                    visible: root.totalCount > 0
                    width: countBadge.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: Colors.md3.primary_container

                    Text {
                        id: countBadge
                        anchors.centerIn: parent
                        text: root.totalCount.toString()
                        color: Colors.md3.on_primary_container
                        font.pixelSize: 12
                        font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                    }
                }

                Item { Layout.fillWidth: true }

                // Limpiar activas
                Rectangle {
                    visible: root.activeCount > 0
                    height: 28
                    width: clearActiveLabel.implicitWidth + 16
                    radius: 14
                    color: Colors.md3.surface_container_high

                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: Colors.md3.on_surface
                        opacity: clearActiveArea.containsMouse ? 0.12 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    Text {
                        id: clearActiveLabel
                        anchors.centerIn: parent
                        text: qsTr("Limpiar activas")
                        color: Colors.md3.on_surface_variant
                        font.pixelSize: 11
                        font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                    }

                    MouseArea {
                        id: clearActiveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.NotificationService.clearActiveNotifications()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.md3.outline_variant
                opacity: 0.5
            }

            // ── Lista con scroll ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: listColumn.implicitHeight
                ScrollBar.vertical: ScrollBar {}

                Column {
                    id: listColumn
                    width: parent.width
                    spacing: 8

                    // ── Notificaciones activas ─────────────────────────────
                    Repeater {
                        model: Services.NotificationService.notifications

                        delegate: Item {
                            id: activeDelegate
                            required property var modelData

                            width: listColumn.width
                            height: activeItem.implicitHeight

                            NotificationItem {
                                id: activeItem
                                width: parent.width
                                notification: activeDelegate.modelData
                                compact: false

                                onDismissed: Qt.callLater(() => activeDelegate.modelData.expire())
                                onActionInvoked: function(identifier) {
                                    activeDelegate.modelData.invokeAction(identifier)
                                }
                            }
                        }
                    }

                    // ── Cabecera historial ─────────────────────────────────
                    RowLayout {
                        width: listColumn.width
                        visible: root.safeHistory.length > 0

                        Text {
                            text: qsTr("Recientes")
                            color: Colors.md3.on_surface_variant
                            font.pixelSize: 11
                            font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 24
                            width: clearHistoryLabel.implicitWidth + 16
                            radius: 12
                            color: Colors.md3.error_container

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Colors.md3.on_surface
                                opacity: clearHistoryArea.containsMouse ? 0.12 : 0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }

                            Text {
                                id: clearHistoryLabel
                                anchors.centerIn: parent
                                text: qsTr("Borrar todo")
                                color: Colors.md3.on_error_container
                                font.pixelSize: 11
                                font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                            }

                            MouseArea {
                                id: clearHistoryArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.NotificationService.clearHistory()
                            }
                        }
                    }

                    Rectangle {
                        width: listColumn.width
                        height: 1
                        color: Colors.md3.outline_variant
                        opacity: 0.4
                        visible: root.safeHistory.length > 0
                    }

                    // ── Historial ──────────────────────────────────────────
                    Repeater {
                        model: root.safeHistory

                        delegate: Item {
                            id: historyDelegate
                            required property var modelData

                            width: listColumn.width
                            height: historyItem.implicitHeight

                            // FIX JSValue: copia local en el engine correcto
                            readonly property var localData: modelData ? ({
                                id:       modelData.id      ?? "",
                                appName:  modelData.appName ?? "",
                                appIcon:  modelData.appIcon ?? "",
                                summary:  modelData.summary ?? "",
                                body:     modelData.body    ?? "",
                                urgency:  modelData.urgency ?? 1,
                                time:     modelData.time    ?? 0,
                                hasImage: false,
                                image:    "",
                                actions:  []
                            }) : null

                            NotificationItem {
                                id: historyItem
                                width: parent.width
                                notification: historyDelegate.localData
                                compact: true
                                onDismissed: Services.NotificationService.removeFromHistory(
                                    historyDelegate.modelData.id
                                )
                            }
                        }
                    }
                }
            }

            // ── Estado vacío ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.totalCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "notifications"
                        size: 40
                        color: Colors.md3.on_surface
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Sin notificaciones")
                        color: Colors.md3.on_surface_variant
                        font.pixelSize: 14
                        font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                    }
                }
            }
        }
    }
}