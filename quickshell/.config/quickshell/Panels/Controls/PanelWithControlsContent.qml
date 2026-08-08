// PanelWithControlsContent — Content
// Toda la UI del panel. Sin fondos ni sombras — eso es responsabilidad de PanelWithControls.
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
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
    required property var    btAdapter
    required property var    audioSink

    readonly property bool btEnabled:   btAdapter ? btAdapter.enabled : false
    readonly property bool wifiEnabled: Networking.wifiEnabled

    readonly property var tabModel: [
        { label: Services.I18nService.getTranslation("panel.system",  "System"),  icon: "memory"        },
        //{ label: Services.I18nService.getTranslation("panel.weather", "Weather"), icon: "filter_drama"  }
    ]

    implicitHeight: mainColumn.implicitHeight + 24

    // ── Helper ─────────────────────────────────────────────────────
    function withAlpha(hex, a) {
        const c = Qt.color(hex)
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // ── UI ─────────────────────────────────────────────────────────────
    ColumnLayout {
        id: mainColumn
        anchors {
            top:    parent.top
            left:   parent.left
            right:  parent.right
            margins: 16
            topMargin: 20
        }
        spacing: 14

        // ══ HEADER — avatar + nombre ════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Avatar
            Item {
                Layout.preferredWidth: 52; Layout.preferredHeight: 52

                Rectangle {
                    id: avatarRing
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.md3.primary_container
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        border.color: Appearance.md3.primary
                        border.width: 2
                        Image {
                            anchors.fill: parent
                            source: Quickshell.env("HOME") + "/.face"
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 52; sourceSize.height: 52
                        }
                    }
                }
            }

            // Nombre + hostname
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

            // Botón apagar sesión (estilo GNOME)
            Rectangle {
                Layout.preferredWidth: 36; 
                Layout.preferredHeight: 36
                radius: 18
                color: powerArea.containsMouse
                    ? root.withAlpha(Appearance.md3.on_surface, 0.10)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "power_settings_new"
                    size: Appearance.font.pixelSize.large
                    color: Appearance.md3.on_surface_variant
                }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: button.running = true
                    Process {
                        id: button
                        command: ["bash", "-c", "qs ipc call ui.powermenu togglePowerMenu"]
                    }
                }
            }
        }
        

        // ══ SLIDERS — Volumen + Brillo ══════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            // Volumen
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialIcon {
                    icon: Services.AudioService.materialIcon
                    size: Appearance.font.pixelSize.large
                    color: Appearance.md3.on_surface_variant
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Services.AudioService.audio)
                                Services.AudioService.audio.muted = !Services.AudioService.audio.muted
                        }
                    }
                }

                // Track del slider
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    // Pista trasera
                    Rectangle {
                        id: volTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: root.withAlpha(Appearance.md3.on_surface, 0.12)

                        // Relleno activo
                        Rectangle {
                            width: volTrack.width * (Services.AudioService.volume ?? 0)
                            height: parent.height
                            radius: parent.radius
                            color: Appearance.md3.primary
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                    }

                    // Thumb
                    Rectangle {
                        x: volTrack.width * (Services.AudioService.volume ?? 0) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        radius: 9
                        color: Appearance.md3.primary
                        border.color: Appearance.md3.surface_container_high
                        border.width: 2
                        Behavior on x { NumberAnimation { duration: 80 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPositionChanged: mouse => {
                            if (pressed && Services.AudioService.audio) {
                                const v = Math.max(0, Math.min(1, mouse.x / width))
                                Services.AudioService.audio.volume = v
                            }
                        }
                        onClicked: mouse => {
                            if (Services.AudioService.audio) {
                                const v = Math.max(0, Math.min(1, mouse.x / width))
                                Services.AudioService.audio.volume = v
                            }
                        }
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                StyledText {
                    text: Math.round((Services.AudioService.volume ?? 0) * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface_variant
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 32
                }
            }

            // Brillo
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: Services.BrightnessService.ready

                MaterialIcon {
                    icon: {
                        const b = Services.BrightnessService.brightness
                        if (b > 0.6) return "brightness_high"
                        if (b > 0.3) return "brightness_medium"
                        return "brightness_low"
                    }
                    size: Appearance.font.pixelSize.large
                    color: Appearance.md3.on_surface_variant
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    Rectangle {
                        id: briTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: root.withAlpha(Appearance.md3.on_surface, 0.12)

                        Rectangle {
                            width: briTrack.width * Services.BrightnessService.brightness
                            height: parent.height
                            radius: parent.radius
                            color: Appearance.md3.tertiary
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                    }

                    Rectangle {
                        x: briTrack.width * Services.BrightnessService.brightness - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        radius: 9
                        color: Appearance.md3.tertiary
                        border.color: Appearance.md3.surface_container_high
                        border.width: 2
                        Behavior on x { NumberAnimation { duration: 80 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPositionChanged: mouse => {
                            if (pressed) {
                                const v = Math.max(0.05, Math.min(1.0, mouse.x / width))
                                Services.BrightnessService.setBrightness(v)
                            }
                        }
                        onClicked: mouse => {
                            const v = Math.max(0.05, Math.min(1.0, mouse.x / width))
                            Services.BrightnessService.setBrightness(v)
                        }
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                StyledText {
                    text: Math.round(Services.BrightnessService.brightness * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface_variant
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 32
                }
            }
        }

        // ══ DIVISOR ════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.withAlpha(Appearance.md3.outline_variant, 0.5)
        }

        // ══ TOGGLES — chips estilo M3/GNOME ════════════════════════
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            ControlToggle {
                Layout.fillWidth: true
                label:    Services.I18nService.getTranslation("panel.wifi", "WiFi")
                iconName: root.wifiEnabled ? "wifi" : "wifi_off"
                active:   root.wifiEnabled
                enabled:  Networking.wifiHardwareEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            ControlToggle {
                Layout.fillWidth: true
                label:    Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
                iconName: root.btEnabled ? "bluetooth" : "bluetooth_disabled"
                active:   root.btEnabled
                enabled:  root.btAdapter !== null
                onToggled: {
                    if (root.btAdapter)
                        root.btAdapter.enabled = !root.btAdapter.enabled
                }
            }

            ControlToggle {
                Layout.fillWidth: true
                label: Services.IdleInhibitedService.inhibited
                    ? Services.I18nService.getTranslation("panel.caffeine_on",  "Caffeine On")
                    : Services.I18nService.getTranslation("panel.caffeine_off", "Caffeine Off")
                iconName: "local_cafe"
                active:   Services.IdleInhibitedService.inhibited
                onToggled: Services.IdleInhibitedService.toggle()
            }

            ControlToggle {
                Layout.fillWidth: true
                label:    Services.I18nService.getTranslation("panel.dnd", "No molestar")
                iconName: "bedtime"
                active:   NotificationManager.dnd
                onToggled: NotificationManager.toggleDnd()
            }
        }

        // ══ DIVISOR ════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.withAlpha(Appearance.md3.outline_variant, 0.5)
        }

        // ══ NAV BAR — tabs estilo M3 Navigation Bar ════════════════
        Item {
            id: navBar
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            property int currentIndex: 0

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.tabModel

                    delegate: Item {
                        id: tabItem
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: navBar.height

                        readonly property bool isActive: navBar.currentIndex === index

                        // Indicador pill debajo del icono (como MD3 Nav Bar)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            width: parent.isActive ? 56 : 0
                            height: 28
                            radius: 14
                            color: Appearance.md3.secondary_container
                            opacity: parent.isActive ? 1 : 0
                            Behavior on width   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        ColumnLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            spacing: 2

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: tabItem.modelData.icon
                                size: 20
                                color: tabItem.isActive
                                    ? Appearance.md3.on_secondary_container
                                    : Appearance.md3.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: tabItem.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: tabItem.isActive ? Font.Medium : Font.Normal
                                color: tabItem.isActive
                                    ? Appearance.md3.on_surface
                                    : Appearance.md3.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: navBar.currentIndex = tabItem.index
                        }
                    }
                }
            }
        }

        // ══ CONTENIDO del tab activo ════════════════════════════════
        StackLayout {
            Layout.fillWidth: true
            currentIndex: navBar.currentIndex

            SysInfoTab {}
        }
    }
}
