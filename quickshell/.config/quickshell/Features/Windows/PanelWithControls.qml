import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import "../../Core/Services" as Services
import "../../Components"
import "../../Core/"

PopupWindow {
    id: root
    grabFocus: true
    color: "transparent"
    implicitWidth: 340
    implicitHeight: content.implicitHeight

    property string username: Quickshell.env("USER")
    property string hostname: ""

    // ── PwObjectTracker fuera del árbol visual ─────────────────
    PwObjectTracker {
        id: pwTracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // ── Accesos seguros a los adapters ────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    readonly property var audioSink: pwTracker.objects.length > 0 ? pwTracker.objects[0] : null
    readonly property bool wifiEnabled: Networking.wifiEnabled

    Process {
        command: ["hostname"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hostname = this.text.trim()
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false);
        }
    }

    // ── M3 elevation shadow level 2 ───────────────────────────
    Rectangle {
        anchors.centerIn: content
        width: content.width + 2
        height: content.height + 8
        radius: content.radius + 1
        color: Colors.md3.shadow ?? "#000000"
        opacity: 0.10
        z: -2
    }
    Rectangle {
        anchors.centerIn: content
        anchors.verticalCenterOffset: 3
        width: content.width + 1
        height: content.height + 4
        radius: content.radius
        color: Colors.md3.shadow ?? "#000000"
        opacity: 0.06
        z: -1
    }

    // ── M3 Surface Container — shape extraLarge (28 dp) ───────
    Rectangle {
        id: content
        anchors.fill: parent
        radius: 28
        color: Colors.md3.surface
        clip: true
        implicitHeight: mainColumn.implicitHeight + 24

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

            // ── Perfil ────────────────────────────────────────
            RowLayout {
                spacing: 14

                // Avatar — M3 circular image + ring outline
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
                    spacing: 1
                    Layout.fillWidth: true

                    Text {
                        text: root.username || "usuario"
                        color: Colors.md3.on_surface
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.family: Services.ConfigService.getConfig("fontSans") ?? "sans-serif"
                    }

                    Text {
                        text: root.hostname || "localhost"
                        color: Colors.md3.on_surface_variant
                        font.pixelSize: 12
                        font.family: Services.ConfigService.getConfig("fontSans") ?? "sans-serif"
                    }
                }
            }

            // ── Divisor M3 — outline_variant al 40 % ─────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.md3.outline_variant
                opacity: 0.4
            }

            // ── Toggles ───────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                ControlToggle {
                    Layout.fillWidth: true
                    label: "WiFi"
                    iconName: root.wifiEnabled ? "wifi" : "wifi_off"
                    active: root.wifiEnabled
                    enabled: Networking.wifiHardwareEnabled
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                ControlToggle {
                    Layout.fillWidth: true
                    label: "Bluetooth"
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
                    label: Services.IdleInhibitedService.inhibited ? "Idle On" : "Idle Off"
                    iconName: "bedtime"
                    active: Services.IdleInhibitedService.inhibited
                    onToggled: Services.IdleInhibitedService.toggle()
                }
            }

            // ── Sliders ───────────────────────────────────────
            // (espacio reservado para futuros sliders de volumen/brillo)
            Item {
                height: 4
            }

            ColumnLayout {
                TabBar {
                    id: navBar
                    Layout.fillWidth: true

                    background: Rectangle {
                        color: Colors.md3.surface_container
                        radius: 0

                        // Línea indicadora inferior M3
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
                                label: "System",
                                icon: "󰍛"
                            }  // nerd font / unicode
                            ,
                            {
                                label: "Wallpapers",
                                icon: "wallpaper"
                            },
                        ]

                        TabButton {
                            required property var modelData
                            required property int index

                            text: modelData.label
                            width: Math.max(80, navBar.width / 2)

                            // ── Estado activo / inactivo ──────────────────────────
                            readonly property bool active: navBar.currentIndex === index
                            readonly property color fgColor: active ? Colors.md3.primary : Colors.md3.on_surface_variant

                            // ── Indicador pill debajo del contenido ───────────────
                            background: Item {
                                // State layer hover/press
                                Rectangle {
                                    anchors.fill: parent
                                    color: parent.parent.active ? Colors.md3.primary : Colors.md3.on_surface_variant
                                    opacity: parent.parent.hovered ? 0.08 : parent.parent.pressed ? 0.12 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 100
                                        }
                                    }
                                }

                                // Pill indicator (M3 style)
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.parent.active ? 64 : 0
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

                            // ── Contenido: icono + texto en columna ───────────────
                            contentItem: ColumnLayout {
                                spacing: 2

                                // Cambia esto por tu sistema de iconos preferido:
                                // - Text con nerd fonts
                                // - Image / Svg source
                                // - Quickshell MaterialIcon si lo tienes
                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    icon: modelData.icon
                                    size: 20
                                    color: parent.parent.fgColor

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
                                    font.weight: parent.parent.active ? Font.Medium : Font.Normal
                                    color: parent.parent.fgColor

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }

                            // Altura fija M3 (nav bar secundaria = 48–64dp)
                            implicitHeight: 64
                            padding: 0
                            topPadding: 10
                            bottomPadding: 10
                        }
                    }
                }
            }
        }
    }
}
