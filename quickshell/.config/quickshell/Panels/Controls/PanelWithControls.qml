// ControlPanel — Wrapper Material 3 Expressive
// Gestiona estado, ciclo de vida y ensambla Background + Content.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Core.Services
import qs.Shared.Background
import Quickshell.Hyprland
import qs.Core
import Quickshell.Wayland

PanelWindow {
    id: root

    color: "transparent"
    implicitWidth: 410
    implicitHeight: panelContent.implicitHeight + 120

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:dashboard"
    exclusiveZone: 0
    visible: false

    anchors {
        left: true
    }

    margins {
        left: visible ? 8 : -implicitWidth - 40
    }
 
    Behavior on margins.left {
        id: slideAnim
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    IpcHandler {
        target: "dashboard"
        function toggle() {
            root.visible = !root.visible;
        }
    }

    // ── Datos ──────────────────────────────────────────────────────
    property string username: Quickshell.env("USER")
    property string hostname: ""

    readonly property var btAdapter: BluetoothService.currentAdapter
    readonly property var audioSink: AudioService.audio

    Process {
        command: ["hostname"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hostname = this.text.trim()
        }
    }

    // ── Ciclo de vida ──────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    // ── Background & Sombra Tonal M3 Expressive ────────────────────
    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow ?? "#000000"
        shadowOpacity: 0.20
        shadowBlur: 0.8
        shadowVerticalOffset: 4
        shadowHorizontalOffset: 2
        z: -1
    }

    PopupBackground {
        id: bg
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: root.implicitHeight
        radius: Appearance.shape.verylarge
        color: Appearance.md3.surface
    }

    // ── Content ────────────────────────────────────────────────────
    PanelWithControlsContent {
        id: panelContent
        anchors {
            top: bg.top
            left: bg.left
            right: bg.right
        }
        username: root.username
        hostname: root.hostname
        btAdapter: root.btAdapter
        audioSink: root.audioSink
    }
}

