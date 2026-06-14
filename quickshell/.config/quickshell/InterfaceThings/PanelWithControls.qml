import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import "../Services" as Services
import "../Components"
import ".."

PopupWindow {
    id: root
    grabFocus: true
    color: "transparent"
    implicitWidth: 340
    implicitHeight: content.implicitHeight

    property string username: ""
    property string hostname: ""

    // ── PwObjectTracker fuera del árbol visual ────────────────
    PwObjectTracker {
        id: pwTracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // ── Accesos seguros a los adapters ────────────────────────
    // Bluetooth: el enabled está en defaultAdapter, no en el singleton
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    readonly property var audioSink: pwTracker.objects.length > 0 ? pwTracker.objects[0] : null

    // WiFi: Networking tiene wifiEnabled directamente como propiedad global
    readonly property bool wifiEnabled: Networking.wifiEnabled

    Process {
        command: ["sh", "-c", "echo $USER"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.username = this.text.trim()
        }
    }

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

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "transparent"
        border.color: Colors.outline
        border.width: 1
        z: 10
    }

    Rectangle {
        id: content
        anchors.fill: parent
        radius: 20
        color: Colors.surface
        clip: true
        implicitHeight: mainColumn.implicitHeight + 32

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

                Rectangle {
                    width: 52
                    height: 52
                    radius: 26
                    color: Colors.surface_variant
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "/home/oscar/.face"
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 52
                        sourceSize.height: 52
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 26
                        color: "transparent"
                        border.color: Qt.alpha(Colors.outline, 0.5)
                        border.width: 1
                    }
                }

                Column {
                    spacing: 2
                    Layout.fillWidth: true

                    Text {
                        text: root.username || "usuario"
                        color: Colors.on_surface
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    }

                    Text {
                        text: root.hostname || "localhost"
                        color: Colors.on_surface_variant
                        font.pixelSize: 12
                        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.outline_variant
                opacity: 0.5
            }

            // ── Toggles ───────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                // ✅ WiFi: Networking.wifiEnabled es la propiedad global correcta
                ControlToggle {
                    Layout.fillWidth: true
                    label: "WiFi"
                    iconName: root.wifiEnabled ? "network-wireless" : "network-wireless-offline"
                    active: root.wifiEnabled
                    enabled: Networking.wifiHardwareEnabled  // desactiva si hay bloqueo hardware
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                // ✅ Bluetooth: enabled está en defaultAdapter
                ControlToggle {
                    Layout.fillWidth: true
                    label: "Bluetooth"
                    iconName: root.btEnabled ? "bluetooth" : "bluetooth-disabled"
                    active: root.btEnabled
                    enabled: root.btAdapter !== null
                    onToggled: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                }

                ControlToggle {
                    Layout.fillWidth: true
                    label: Services.IdleInhibitedService.inhibited ? "Idle On" : "Idle off"
                    iconName: "night-light"
                    active: Services.IdleInhibitedService.inhibited
                    onToggled: Services.IdleInhibitedService.toggle()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.outline_variant
                opacity: 0.5
            }

            // ── Sliders ───────────────────────────────────────
            Column {
                Layout.fillWidth: true
                spacing: 12

                // ✅ Volumen: acceso correcto via pwTracker
                ControlSlider {
                    width: parent.width
                    label: "Volumen"
                    iconName: {
                        const muted = root.audioSink?.audio?.muted ?? true;
                        const vol = root.audioSink?.audio?.volume ?? 0;
                        if (muted || vol === 0)
                            return "audio-volume-muted";
                        if (vol < 0.33)
                            return "audio-volume-low";
                        if (vol < 0.66)
                            return "audio-volume-medium";
                        return "audio-volume-high";
                    }
                    value: root.audioSink?.audio?.volume ?? 0
                    enabled: root.audioSink !== null
                    onMoved: val => {
                        if (root.audioSink?.audio)
                            root.audioSink.audio.volume = val;
                    }
                }

                ControlSlider {
                    width: parent.width
                    label: "Brillo"
                    iconName: {
                        const b = Services.BrightnessService.brightness;
                        if (b < 0.33)
                            return "display-brightness-low";
                        if (b < 0.66)
                            return "display-brightness-medium";
                        return "display-brightness";
                    }
                    value: Services.BrightnessService.brightness
                    onMoved: val => Services.BrightnessService.setBrightness(val)
                }
            }
        }
    }
}
