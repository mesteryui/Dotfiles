// PanelWithControlsContent — Content Material 3 Expressive
// Toda la UI del panel construida con qs.Primitives.
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import qs.Core.Services as Services
import qs.Primitives
import qs.Core
import Quickshell.Widgets
import qs.Panels.Controls.Tabs
import qs.Features.Notifications
import Quickshell.Io

Item {
    id: root

    // ── Datos recibidos del Wrapper ────────────────────────────────
    required property string username
    required property string hostname
    required property var btAdapter
    required property var audioSink

    readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false
    readonly property bool wifiEnabled: Networking.wifiEnabled

    readonly property var tabModel: [
        {
            label: Services.I18nService.getTranslation("panel.system", "Sistema"),
            icon: "memory"
        }
    ]

    // Alto "natural" (sin recortar) que el Wrapper usa para decidir si
    // hace falta activar el scroll. El Item en sí se estira al alto que
    // le dé el Wrapper (posiblemente menor que este valor).
    readonly property int naturalHeight: mainColumn.implicitHeight + 44

    // ── Helper ─────────────────────────────────────────────────────
    function withAlpha(hex, a) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ── UI Principal (scrolleable) ───────────────────────────────────
    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 44

        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        ColumnLayout {
            id: mainColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 20
                topMargin: 24
            }
            spacing: 16

            // ══ HEADER — Avatar + Usuario + Power button ═════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Avatar con marco M3 Expressive
                Item {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52

                    Rectangle {
                        id: avatarRing
                        anchors.fill: parent
                        radius: width / 2
                        color: Appearance.md3.primary_container

                        StyledClippingRectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            border.color: Appearance.md3.primary
                            border.width: 2

                            Image {
                                anchors.fill: parent
                                source: Quickshell.env("HOME") + "/.face"
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 52
                                sourceSize.height: 52
                            }
                        }
                    }
                }

                // Nombre + Hostname
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: root.username || "usuario"
                        color: Appearance.md3.on_surface
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        font.family: Appearance.font.sans
                    }
                    StyledText {
                        text: root.hostname || "localhost"
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.sans
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Botón apagar sesión (Power Button con micro-animación)
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: powerArea.pressed ? root.withAlpha(Appearance.md3.error_container, 0.9) : (powerArea.containsMouse ? root.withAlpha(Appearance.md3.error_container, 0.4) : Appearance.md3.surface_container_high)

                    scale: powerArea.pressed ? 0.92 : (powerArea.containsMouse ? 1.06 : 1.0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "power_settings_new"
                        size: Appearance.font.pixelSize.large
                        color: powerArea.containsMouse ? Appearance.md3.error : Appearance.md3.on_surface_variant
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: buttonProc.running = true

                        Process {
                            id: buttonProc
                            command: ["bash", "-c", "qs ipc call ui.powermenu togglePowerMenu"]
                        }
                    }
                }
            }

            // ══ SLIDERS — Volumen + Brillo (usando Primitives.ControlSlider) ══
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // Volumen
                ControlSlider {
                    Layout.fillWidth: true
                    iconName: Services.AudioService.materialIcon
                    value: Services.AudioService.volume ?? 0
                    accentColor: Appearance.md3.primary
                    onMoved: val => {
                        if (Services.AudioService.audio) {
                            Services.AudioService.audio.volume = val;
                        }
                    }
                    onIconClicked: {
                        if (Services.AudioService.audio) {
                            Services.AudioService.audio.muted = !Services.AudioService.audio.muted;
                        }
                    }
                }

                // Brillo
                ControlSlider {
                    Layout.fillWidth: true
                    visible: Services.BrightnessService.ready
                    iconName: {
                        const b = Services.BrightnessService.brightness;
                        if (b > 0.6)
                            return "brightness_high";
                        if (b > 0.3)
                            return "brightness_medium";
                        return "brightness_low";
                    }
                    value: Services.BrightnessService.brightness
                    accentColor: Appearance.md3.tertiary
                    onMoved: val => Services.BrightnessService.setBrightness(val)
                }
            }

            // ══ DIVISOR ════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
            }

            // ══ TOGGLES — Quick Settings (usando Primitives.ControlToggle) ══
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 10
                uniformCellWidths: true

                // WiFi
                ControlToggle {
                    Layout.fillWidth: true
                    iconName: root.wifiEnabled ? "wifi" : "wifi_off"
                    label: Services.I18nService.getTranslation("panel.wifi", "WiFi")
                    stateText: root.wifiEnabled ? Services.I18nService.getTranslation("panel.connected", "Conectado") : Services.I18nService.getTranslation("panel.disconnected", "Desconectado")
                    active: root.wifiEnabled
                    enable: Networking.wifiHardwareEnabled
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                // Bluetooth
                ControlToggle {
                    Layout.fillWidth: true
                    iconName: root.btEnabled ? "bluetooth" : "bluetooth_disabled"
                    label: Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
                    stateText: root.btEnabled ? Services.I18nService.getTranslation("panel.on", "Activado") : Services.I18nService.getTranslation("panel.off", "Desactivado")
                    active: root.btEnabled
                    enable: root.btAdapter !== null
                    onToggled: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                }

                // Cafeína
                ControlToggle {
                    Layout.fillWidth: true
                    iconName: "local_cafe"
                    label: Services.I18nService.getTranslation("panel.caffeine", "Cafeína")
                    stateText: Services.IdleInhibitedService.inhibited ? Services.I18nService.getTranslation("panel.caffeine_on", "Activada") : Services.I18nService.getTranslation("panel.caffeine_off", "Desactivada")
                    active: Services.IdleInhibitedService.inhibited
                    onToggled: Services.IdleInhibitedService.toggle()
                }

                // No Molestar
                ControlToggle {
                    Layout.fillWidth: true
                    iconName: NotificationManager.dnd ? "bedtime" : "notifications"
                    label: Services.I18nService.getTranslation("panel.dnd", "No molestar")
                    stateText: NotificationManager.dnd ? Services.I18nService.getTranslation("panel.dnd_on", "Activado") : Services.I18nService.getTranslation("panel.dnd_off", "Desactivado")
                    active: NotificationManager.dnd
                    onToggled: NotificationManager.toggleDnd()
                }
                ControlToggle {
                    Layout.fillWidth: true
                    iconName: Services.Hyprsunset.nightLightActive ? "bedtime" : "bedtime"
                    label: Services.I18nService.getTranslation("panel.night_light", "Luz nocturna")
                    stateText: Services.Hyprsunset.nightLightActive ? Services.I18nService.getTranslation("panel.night_light_onf", "Activado") : Services.I18nService.getTranslation("panel.nightlight_off", "Desactivado")
                    active: Services.Hyprsunset.nightLightActive
                    onToggled: Services.Hyprsunset.toggleNightLight()
                }
                ControlToggle {
                    Layout.fillWidth: true
                    iconName: "gamepad"
                    label: Services.I18nService.getTranslation("panel.gameMode", "Modo de Juego")
                    stateText: Services.GameMode.enabled ? Services.I18nService.getTranslation("panel.night_light_onf", "Activado") : Services.I18nService.getTranslation("panel.nightlight_off", "Desactivado")
                    active: Services.GameMode.enabled
                    onToggled: Services.GameMode.toggle()
                }
            }

            // ══ DIVISOR ════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
            }

            TabBar {
                id: tabBar
            }

            // ══ CONTENIDO del Tab activo ════════════════════════════════
            StackLayout {
                Layout.fillWidth: true

                SysInfoTab {}
            }
        }
    }
}
