// PanelWithControlsContent — Content
// Toda la UI del panel. Sin fondos ni sombras — eso es responsabilidad de PanelWithControls.
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell.Networking
import qs.Core.Services as Services
import qs.Primitives
import qs.Core
import Quickshell.Widgets
import qs.Panels.Controls.Tabs

Item {
    id: root

    // ── Datos recibidos del Wrapper ────────────────────────────────
    required property string username
    required property string hostname
    required property var btAdapter
    required property var audioSink

    readonly property bool btEnabled: btAdapter?.enabled ?? falsese
        readonly property bool wifiEnabled: Networking.wifiEnabled
            readonly property var tabModel: [
            { label: Services.I18nService.getTranslation("panel.system", "System"), icon: "memory" },
            { label: Services.I18nService.getTranslation("panel.weather", "Weather"), icon: "filter_drama" }
            ]
            implicitHeight: mainColumn.implicitHeight + 24

            // ── UI ─────────────────────────────────────────────────────────
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

                // ── Perfil ─────────────────────────────────────────────────
                RowLayout {
                    spacing: 14

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: Colors.md3.primary_container ?? Colors.md3.surface_variant
                        clip: true

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            border.color: Colors.md3.primary
                            border.width: 2

                            Image {
                                anchors.fill: parent
                                source: Quickshell.env("HOME") + "/.face"
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 48
                                sourceSize.height: 48
                            }
                        }

                    }

                    Column {
                        spacing: 2
                        Layout.fillWidth: true

                        StyledText {
                            text: root.username || Services.I18nService.getTranslation("panel.user", "usuario")
                            color: Colors.md3.on_surface
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            font.family: Services.ConfigService.configs.appearence.fontSans
                        }

                        StyledText {
                            text: root.hostname || Services.I18nService.getTranslation("panel.host", "localhost")
                            color: Colors.md3.on_surface_variant
                            font.pixelSize: 12
                            font.family: Services.ConfigService.configs.appearence.fontSans
                        }

                    }
                }

                // ── Divisor ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.md3.outline_variant
                    opacity: 0.4
                }

                // ── Toggles ────────────────────────────────────────────────
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
                                root.btAdapter.enabled = !root.btAdapter.enabled
                        }
                    }

                    ControlToggle {
                        Layout.fillWidth: true
                        label: Services.IdleInhibitedService.inhibited
                        ? Services.I18nService.getTranslation("panel.caffeine_on", "Caffeine On")
                        : Services.I18nService.getTranslation("panel.caffeine_off", "Caffeine Off")
                        iconName: "local_cafe"
                        active: Services.IdleInhibitedService.inhibited
                        onToggled: Services.IdleInhibitedService.toggle()
                    }
                }

                // ── TabBar ─────────────────────────────────────────────────
                TabBar {
                    id: navBar
                    Layout.fillWidth: true

                    Material.accent: Colors.md3.primary
                    Material.background: Colors.md3.surface_container
                    Material.foreground: Colors.md3.on_surface
                    Material.roundedScale: Material.FullScale
                    

                    Repeater {
                        model: root.tabModel

                        TabButton {
                            id: tabButton
                            required property var modelData
                            required property int index

                            readonly property color fgColor: checked
                                ? Colors.md3.primary
                                : Colors.md3.on_surface_variant

                                text: modelData.label
                                Layout.fillWidth: true
                                implicitHeight: 64
                                padding: 0
                                topPadding: 10
                                bottomPadding: 10


                                contentItem: ColumnLayout {
                                    spacing: 2

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        icon: modelData.icon
                                        size: 20
                                        color: tabButton.fgColor
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.weight: tabButton.checked ? Font.Medium : Font.Normal
                                        color: tabButton.fgColor
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }
                            }
                        }
                    }

                    // ── Tabs — hermano del TabBar, no hijo ─────────────────────
                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: navBar.currentIndex

                        SysInfoTab {}
                        WeatherTab {}
                    }
                }
            }
