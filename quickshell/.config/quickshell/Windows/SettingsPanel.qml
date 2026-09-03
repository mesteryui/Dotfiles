import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Core
import qs.Shared.Background
import QtQuick.Controls

ApplicationWindow {
    id: root

    flags: Qt.FramelessWindowHint
    color: "transparent"

    width: 460
    height: 720
    title: "ShinroShell Settings"
    visible: false

    // Posicionamiento dinámico para ApplicationWindow
    y: visible ? 30 : -height - 40

    Behavior on y {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    // ── IPC ──────────────────────────────────────────────────────────
    // qs ipc call ui.settings toggle
    IpcHandler {
        target: "ui.settings"
        function toggle() {
            root.visible = !root.visible;
        }
        function open() {
            root.visible = true;
        }
        function close() {
            root.visible = false;
        }
    }

    // ── Ciclo de vida ────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    // ── Background & Sombra Tonal M3 Expressive ─────────────────────
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
        anchors.fill: parent
        surfaceRadius: 0
        baseColor: Appearance.md3.surface
        showBorder: false
    }

    // ── Content ──────────────────────────────────────────────────────
    SettingsPanelContent {
        id: settingsContent
        anchors.fill: bg
    }
}
