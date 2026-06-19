// --- NotificationItem ---
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Core
import qs.Core.Services as Services

Rectangle {
    id: root

    required property var notification
    property bool compact: false

        signal dismissed()
        signal actionInvoked(string identifier)

        readonly property bool isCritical: notification?.urgency === NotificationUrgency.Critical
            readonly property alias hovered: hoverHandler.hovered

                radius: 28
                color: Colors.md3.surface_container_high
                border.width: isCritical ? 2 : 0
                border.color: Colors.md3.error

                implicitWidth: 360
                implicitHeight: inner.implicitHeight + 24

                HoverHandler { id: hoverHandler }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.md3.on_surface
                    opacity: hoverHandler.hovered ? 0.06 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                ColumnLayout {
                    id: inner
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // ── Icono / imagen ──────────────────────────────────────────
                        Item {
                            id: iconSlot
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignTop

                            readonly property string iconName: root.notification?.appIcon ?? ""
                                readonly property string imageSrc: root.notification?.image ?? ""
                                    readonly property bool hasImage: root.notification?.hasImage ?? false

                                        // Imagen adjunta (prioridad)
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            clip: true
                                            color: "transparent"
                                            visible: iconSlot.hasImage && iconSlot.imageSrc !== ""

                                            Image {
                                                anchors.fill: parent
                                                source: iconSlot.imageSrc
                                                fillMode: Image.PreserveAspectCrop
                                            }
                                        }

                                        // Icono XDG del tema (ej: "firefox", "spotify")
                                        IconImage {
                                            id: themedIcon
                                            anchors.fill: parent
                                            visible: !iconSlot.hasImage
                                                && iconSlot.iconName !== ""
                                                && status !== Image.Error
                                            source: ("file:///usr/share/pixmaps/" + iconSlot.iconName + ".png")
                                            ? iconSlot.iconName : ""
                                        }

                                        // Fallback 1: /usr/share/pixmaps/<name>.png
                                        Image {
                                            id: pixmapFallback
                                            anchors.fill: parent
                                            visible: !iconSlot.hasImage
                                                && iconSlot.iconName !== ""
                                                && themedIcon.status === Image.Error
                                                && status !== Image.Error
                                            source: visible
                                            ? ("file:///usr/share/pixmaps/" + iconSlot.iconName + ".png")
                                            : ""
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        // Fallback 2: /usr/share/pixmaps/<name>.svg
                                        Image {
                                            anchors.fill: parent
                                            visible: !iconSlot.hasImage
                                                && iconSlot.iconName !== ""
                                                && themedIcon.status === Image.Error
                                                && pixmapFallback.status === Image.Error
                                            source: visible
                                            ? ("file:///usr/share/pixmaps/" + iconSlot.iconName + ".svg")
                                            : ""
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    // ── Textos ──────────────────────────────────────────────────
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: root.notification?.appName ?? ""
                                            color: Colors.md3.on_surface_variant
                                            font.pixelSize: 11
                                            font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.notification?.summary ?? ""
                                            color: Colors.md3.on_surface
                                            font.bold: true
                                            font.pixelSize: 13
                                            font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: root.notification?.body ?? ""
                                            color: Colors.md3.on_surface_variant
                                            font.pixelSize: 12
                                            font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: root.compact ? 2 : 5
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // ── Botón cerrar ────────────────────────────────────────────
                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        Layout.alignment: Qt.AlignTop

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 14
                                            color: Colors.md3.on_surface
                                            opacity: closeArea.containsMouse ? 0.12 : 0
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: Colors.md3.on_surface_variant
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            id: closeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.dismissed()
                                        }
                                    }
                                }

                                // ── Imagen grande (no-compact) ───────────────────────────────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 110
                                    Layout.topMargin: 2
                                    visible: !root.compact && (root.notification?.hasImage ?? false)
                                    radius: 16
                                    clip: true
                                    color: "transparent"

                                    Image {
                                        anchors.fill: parent
                                        source: root.notification?.image ?? ""
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }

                                // ── Acciones ─────────────────────────────────────────────────────
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    visible: !root.compact && actionsRepeater.count > 0
                                    spacing: 8

                                    Repeater {
                                        id: actionsRepeater
                                        model: root.notification?.actions ?? []

                                        delegate: Rectangle {
                                            id: actionRect
                                            required property var modelData

                                            Layout.preferredHeight: 32
                                            Layout.preferredWidth: actionText.implicitWidth + 24
                                            radius: 16
                                            color: Colors.md3.secondary_container

                                            Rectangle {
                                                anchors.fill: parent; radius: parent.radius
                                                color: Colors.md3.on_surface
                                                opacity: actionArea.containsMouse ? 0.12 : 0
                                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                            }

                                            Text {
                                                id: actionText
                                                anchors.centerIn: parent
                                                text: actionRect.modelData?.text ?? ""
                                                color: Colors.md3.on_secondary_container
                                                font.pixelSize: 12
                                                font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
                                            }

                                            MouseArea {
                                                id: actionArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (actionRect.modelData)
                                                    {
                                                        actionRect.modelData.invoke()
                                                        // Subir por el árbol hasta el RowLayout que sí tiene la ref
                                                        // En vez de root.actionInvoked, subir via parent chain
                                                        //actionRect.parent.parent.parent.parent  // frágil — mejor:
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                Item { Layout.preferredHeight: 0 }
                            }
                        }