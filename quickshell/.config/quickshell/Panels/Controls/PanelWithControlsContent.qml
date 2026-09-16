// PanelWithControlsContent — Content Material 3 Expressive
// Toda la UI del panel construida con qs.Primitives.
pragma ComponentBehavior: Bound
import qs.Core.Services as Services
import qs.Primitives
import qs.Core
import qs.Panels.Controls.Tabs
import qs.Features.Notifications
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Widgets

Item {
    id: root

    // ── Datos recibidos del Wrapper ────────────────────────────────
    required property string username
    required property string hostname
    required property var btAdapter
    required property var audioSink

    readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false
    readonly property bool wifiEnabled: Networking.wifiEnabled

    // ── Focus-visible ────────────────────────────────────────────
    // keyboardMode=false → ningún anillo de foco aunque haya foco activo
    // (ratón o foco inicial silencioso). Cualquier tecla lo pone a true y
    // cualquier uso del ratón lo devuelve a false. Así el panel no "grita"
    // el foco hasta que se usa el teclado.
    property bool keyboardMode: false

    function focusDefault() {
        root.keyboardMode = false;
        volumeSlider.forceActiveFocus();
    }

    function focusAboveToggles() {
        if (brightnessSlider.visible)
            brightnessSlider.forceActiveFocus();
        else
            volumeSlider.forceActiveFocus();
    }

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
                    id: powerButton

                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: powerArea.pressed ? root.withAlpha(Appearance.md3.error_container, 0.9) : (powerArea.containsMouse ? root.withAlpha(Appearance.md3.error_container, 0.4) : Appearance.md3.surface_container_high)
                    border.width: (activeFocus && root.keyboardMode) ? 2 : 0
                    border.color: Appearance.md3.primary
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: "Apagar sesión"

                    Keys.onPressed: root.keyboardMode = true
                    Keys.onReturnPressed: buttonProc.running = true
                    Keys.onEnterPressed: buttonProc.running = true
                    Keys.onSpacePressed: buttonProc.running = true
                    Keys.onDownPressed: volumeSlider.forceActiveFocus()

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
                        onEntered: root.keyboardMode = false
                        onPressed: {
                            powerButton.forceActiveFocus();
                            root.keyboardMode = false;
                        }
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
                    id: volumeSlider
                    Layout.fillWidth: true
                    iconName: Services.AudioService.materialIcon
                    value: Services.AudioService.volume ?? 0
                    accentColor: Appearance.md3.primary
                    accessibleName: "Volumen"
                    keyboardMode: root.keyboardMode
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
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: powerButton.forceActiveFocus()
                    Keys.onDownPressed: {
                        if (brightnessSlider.visible)
                            brightnessSlider.forceActiveFocus();
                        else
                            wifiToggle.forceActiveFocus();
                    }
                    onMouseUsed: root.keyboardMode = false
                }

                // Brillo
                ControlSlider {
                    id: brightnessSlider
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
                    accessibleName: "Brillo"
                    keyboardMode: root.keyboardMode
                    onMoved: val => Services.BrightnessService.setBrightness(val)
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: volumeSlider.forceActiveFocus()
                    Keys.onDownPressed: wifiToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
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
                    id: wifiToggle
                    Layout.fillWidth: true
                    iconName: root.wifiEnabled ? "wifi" : "wifi_off"
                    label: Services.I18nService.getTranslation("panel.wifi", "WiFi")
                    stateText: root.wifiEnabled ? Services.I18nService.getTranslation("panel.connected", "Conectado") : Services.I18nService.getTranslation("panel.disconnected", "Desconectado")
                    active: root.wifiEnabled
                    enable: Networking.wifiHardwareEnabled
                    keyboardMode: root.keyboardMode
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    KeyNavigation.right: btToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: root.focusAboveToggles()
                    Keys.onDownPressed: cafeToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
                }

                // Bluetooth
                ControlToggle {
                    id: btToggle
                    Layout.fillWidth: true
                    iconName: root.btEnabled ? "bluetooth" : "bluetooth_disabled"
                    label: Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
                    stateText: root.btEnabled ? Services.I18nService.getTranslation("panel.on", "Activado") : Services.I18nService.getTranslation("panel.off", "Desactivado")
                    active: root.btEnabled
                    enable: root.btAdapter !== null
                    keyboardMode: root.keyboardMode
                    onToggled: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                    KeyNavigation.left: wifiToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: root.focusAboveToggles()
                    Keys.onDownPressed: dndToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
                }

                // Cafeína
                ControlToggle {
                    id: cafeToggle
                    Layout.fillWidth: true
                    iconName: "local_cafe"
                    label: Services.I18nService.getTranslation("panel.caffeine", "Cafeína")
                    stateText: Services.IdleInhibitedService.inhibited ? Services.I18nService.getTranslation("panel.caffeine_on", "Activada") : Services.I18nService.getTranslation("panel.caffeine_off", "Desactivada")
                    active: Services.IdleInhibitedService.inhibited
                    keyboardMode: root.keyboardMode
                    onToggled: Services.IdleInhibitedService.toggle()
                    KeyNavigation.right: dndToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: wifiToggle.forceActiveFocus()
                    Keys.onDownPressed: nightToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
                }

                // No Molestar
                ControlToggle {
                    id: dndToggle
                    Layout.fillWidth: true
                    iconName: Services.NotificationService.dnd ? "bedtime" : "notifications"
                    label: Services.I18nService.getTranslation("panel.dnd", "No molestar")
                    stateText: Services.NotificationService.dnd ? Services.I18nService.getTranslation("panel.dnd_on", "Activado") : Services.I18nService.getTranslation("panel.dnd_off", "Desactivado")
                    active: Services.NotificationService.dnd
                    keyboardMode: root.keyboardMode
                    onToggled: Services.NotificationService.toggleDnd()
                    KeyNavigation.left: cafeToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: btToggle.forceActiveFocus()
                    Keys.onDownPressed: gameToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
                }
                ControlToggle {
                    id: nightToggle
                    Layout.fillWidth: true
                    iconName: Services.Hyprsunset.nightLightActive ? "bedtime" : "bedtime"
                    label: Services.I18nService.getTranslation("panel.night_light", "Luz nocturna")
                    stateText: Services.Hyprsunset.nightLightActive ? Services.I18nService.getTranslation("panel.night_light_onf", "Activado") : Services.I18nService.getTranslation("panel.nightlight_off", "Desactivado")
                    active: Services.Hyprsunset.nightLightActive
                    keyboardMode: root.keyboardMode
                    onToggled: Services.Hyprsunset.toggleNightLight()
                    KeyNavigation.right: gameToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: cafeToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
                }
                ControlToggle {
                    id: gameToggle
                    Layout.fillWidth: true
                    iconName: "gamepad"
                    label: Services.I18nService.getTranslation("panel.gameMode", "Modo de Juego")
                    stateText: Services.GameMode.enabled ? Services.I18nService.getTranslation("panel.night_light_onf", "Activado") : Services.I18nService.getTranslation("panel.nightlight_off", "Desactivado")
                    active: Services.GameMode.enabled
                    keyboardMode: root.keyboardMode
                    onToggled: Services.GameMode.toggle()
                    KeyNavigation.left: nightToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: dndToggle.forceActiveFocus()
                    onMouseUsed: root.keyboardMode = false
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
