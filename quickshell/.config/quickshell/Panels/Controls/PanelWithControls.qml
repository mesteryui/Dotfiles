// --- ControlPanel ---
// Panel popup principal: perfil, toggles y tabs de sistema/weather.
// PopupWindow con foco capturado, sombra M3 via MultiEffect.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import qs.Core.Services as Services
import qs.Primitives
import qs.Core
import qs.Panels.Controls.Tabs

PopupWindow {
    id: root
    grabFocus: true
    color: "transparent"
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 16   // margen inferior para la sombra

    property string username: Quickshell.env("USER")
    property string hostname: ""

    // ── PwObjectTracker fuera del árbol visual ─────────────────────────────
    PwObjectTracker {
        id: pwTracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // ── Accesos seguros ────────────────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    readonly property var audioSink: pwTracker.objects.length > 0 ? pwTracker.objects[0] : null
    readonly property bool wifiEnabled: Networking.wifiEnabled

    // ── Hostname ───────────────────────────────────────────────────────────
    Process {
        command: ["hostname"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hostname = this.text.trim()
        }
    }

    // ── Focus grab ────────────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false);
        }
    }

    // ── M3 Elevation shadow level 2 (MultiEffect) ─────────────────────────
    MultiEffect {
        source: content
        anchors.fill: content
        shadowEnabled: true
        shadowColor: Colors.md3.shadow ?? "#000000"
        shadowOpacity: 0.18
        shadowBlur: 0.8
        shadowVerticalOffset: 6
        shadowHorizontalOffset: 0
        z: -1
    }

    // ── M3 Surface — extraLarge (28 dp) ────────────────────────────────────
    Rectangle {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: mainColumn.implicitHeight + 24
        radius: 28
        color: Colors.md3.surface
        clip: true

        ColumnLayout {
            id: mainColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
                topMargin: 20
            }
            spacing: 16

            // ── Perfil ─────────────────────────────────────────────────────
            RowLayout {
                spacing: 14

                // Avatar — ClippingRectangle (Quickshell) evita desborde de imagen
                Rectangle {
                    id: imageRectangle
                    width: 48
                    height: 48
                    radius: 24
                    color: Colors.md3.primary_container ?? Colors.md3.surface_variant
                    clip: true

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: imageRectangle.radius
                        border.color: Colors.md3.primary
                        border.width: 2

                        Image {
                            anchors.fill: parent
                            source: "/home/oscar/.face"
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 48
                            sourceSize.height: 48
                        }
                    }
                }

                // Nombre + host
                Column {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: root.username || Services.I18nService.getTranslation("panel.user", "usuario")
                        color: Colors.md3.on_surface
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.family: Services.ConfigService.getConfig("fontSans") ?? "sans-serif"
                    }

                    Text {
                        text: root.hostname || Services.I18nService.getTranslation("panel.host", "localhost")
                        color: Colors.md3.on_surface_variant
                        font.pixelSize: 12
                        font.family: Services.ConfigService.getConfig("fontSans") ?? "sans-serif"
                    }
                }
            }

            // ── Divisor M3 — outline_variant ──────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.md3.outline_variant
                opacity: 0.4
            }

            // ── Toggles ───────────────────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                ControlToggle {
                    Layout.fillWidth: true
                    label: Services.I18nService.getTranslation("panel.wifi", "WiFi")
                    iconName: root.wifiEnabled ? "wifi" : "wifi_off"
                    active: root.wifiEnabled
                    enabled: Networking.wifiHardwareEnabled
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                ControlToggle {
                    Layout.fillWidth: true
                    label: Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
                    iconName: root.btEnabled ? "bluetooth" : "bluetooth_disabled"
                    active: root.btEnabled
                    enabled: root.btAdapter !== null
                    onToggled: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                }

                ControlToggle {
                    Layout.fillWidth: true
                    label: Services.IdleInhibitedService.inhibited ? Services.I18nService.getTranslation("panel.caffeine_on", "Caffeine On") : Services.I18nService.getTranslation("panel.caffeine_off", "Caffeine Off")
                    iconName: "local_cafe"
                    active: Services.IdleInhibitedService.inhibited
                    onToggled: Services.IdleInhibitedService.toggle()
                }
                //ControlToggle {
                //    Layout.fillWidth: true
                //    label: Services.I18nService.getTranslation("panel.dnd", "Do Not Disturb")
                //    iconName: "bedtime"
                //    active: Services.NotificationService.dnd
                //    onToggled: Services.NotificationService.dnd = !Services.NotificationService.dnd
                //}
            }

            // ── TabBar ────────────────────────────────────────────────────
            TabBar {
                id: navBar
                Layout.fillWidth: true

                background: Rectangle {
                    color: Colors.md3.surface_container
                    radius: 15

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Colors.md3.outline_variant
                    }
                }

                Repeater {
                    model: [
                        {
                            label: Services.I18nService.getTranslation("panel.system", "System"),
                            icon: "memory"
                        },
                        {
                            label: Services.I18nService.getTranslation("panel.weather", "Weather"),
                            icon: "filter_drama"
                        }
                    ]

                    TabButton {
                        id: tabButton
                        required property var modelData
                        required property int index

                        // TabButton hereda AbstractButton: `checked` es true cuando está activo
                        readonly property color fgColor: checked ? Colors.md3.primary : Colors.md3.on_surface_variant

                        text: modelData.label
                        Layout.fillWidth: true
                        implicitHeight: 64
                        padding: 0
                        topPadding: 10
                        bottomPadding: 10

                        background: Item {
                            // State layer hover / press
                            Rectangle {
                                anchors.fill: parent
                                radius: 20
                                color: tabButton.checked ? Colors.md3.primary : Colors.md3.on_surface_variant
                                opacity: tabButton.hovered ? 0.08 : tabButton.pressed ? 0.12 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            // Pill indicator
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: tabButton.checked ? 64 : 0
                                height: 3
                                radius: 2
                                color: Colors.md3.primary
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        contentItem: ColumnLayout {
                            spacing: 2

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: modelData.icon
                                size: 20
                                color: tabButton.fgColor
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                font.pixelSize: 11
                                font.weight: tabButton.checked ? Font.Medium : Font.Normal
                                color: tabButton.fgColor
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── StackLayout — FUERA del TabBar ────────────────────────────
            // Importante: debe ser hermano de TabBar, no hijo.
            StackLayout {
                id: stackLayout
                Layout.fillWidth: true
                currentIndex: navBar.currentIndex

                SysInfoTab {}
                WeatherTab {}
            }
        }
    }
}
