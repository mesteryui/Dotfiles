import qs.Core
import qs.Shared.Background
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

FloatingWindow {
    id: root

    color: "transparent"

    implicitWidth: 460
    implicitHeight: 720
    title: "ShinroShell Settings"
    visible: false

    onClosed: root.visible = false

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
        shadowColor: Appearance.md3.shadow
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

    // ── Content (lazy) ─────────────────────────────────────────
    // SettingsPanelContent es pesado y el panel pasa el 99% del tiempo
    // oculto: se difiere sin cambiar IPC ni comportamiento.
    Loader {
        id: contentLoader

        anchors.fill: bg
        active: root.visible
        asynchronous: true
        sourceComponent: settingsComp
    }

    Component {
        id: settingsComp

        SettingsPanelContent {
            anchors.fill: parent
        }
    }
}
