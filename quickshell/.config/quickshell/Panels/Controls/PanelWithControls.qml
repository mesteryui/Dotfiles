// ControlPanel — Wrapper
// Gestiona estado, ciclo de vida y ensambla Background + Content.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Core.Services
import qs.Shared.Background
import Quickshell.Hyprland
import qs.Core
PopupWindow {
    id: root
    grabFocus: true
    color: "transparent"
    implicitWidth: 340
    implicitHeight: panelContent.implicitHeight + 24   // margen inferior para la sombra

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

    // ── Background ─────────────────────────────────────────────────
    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: Colors.md3.shadow ?? "#000000"
        shadowOpacity: 0.18
        shadowBlur: 0.8
        shadowVerticalOffset: 6
        shadowHorizontalOffset: 0
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
        radius: 28
        color: Colors.md3.surface
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
