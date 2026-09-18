// ControlPanel — Wrapper Material 3 Expressive
// Gestiona estado, ciclo de vida y ensambla Background + Content.

import qs.Core.Services
import qs.Shared.Background
import qs.Core
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    color: "transparent"

    // ── Límites de altura ────────────────────────────────────────────
    // Ajusta barHeight al alto real de tu barra superior (o el gap que
    // quieras respetar si tu barra está en otro borde).

    implicitWidth: 410
    implicitHeight: 800

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:dashboard"
    exclusiveZone: 0
    visible: false

    anchors {
        left: true
        top: true
    }

    margins {
        left: visible ? 8 : -implicitWidth - 40
        top: 30
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on margins.left {
        id: slideAnim

        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle() {
            root.visible = !root.visible;
        }
    }

    // ── Datos ──────────────────────────────────────────────────────
    property string username: Quickshell.env("USER")

    // Sin proceso `hostname` dedicado: viene del bucle de SystemInfoService.
    property string hostname: SystemInfoService.hostname

    readonly property var btAdapter: BluetoothService.currentAdapter

    readonly property var audioSink: AudioService.audio

    // ── Ciclo de vida ──────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    // Demanda pareada sobre SystemInfoService: adquirir al abrir y liberar
    // al cerrar (con guardia para no desbalancear el contador si visible
    // cambia dos veces seguidas al mismo valor, y liberación al destruir).
    property bool _sysInfoAcquired: false

    function syncSysInfoDemand() {
        if (root.visible && !root._sysInfoAcquired) {
            SystemInfoService.acquire();
            root._sysInfoAcquired = true;
        } else if (!root.visible && root._sysInfoAcquired) {
            SystemInfoService.release();
            root._sysInfoAcquired = false;
        }
    }

    Component.onDestruction: {
        if (root._sysInfoAcquired)
            SystemInfoService.release();
    }

    onVisibleChanged: {
        // Foco inicial silencioso: el teclado funciona desde el primer
        // momento pero sin anillo visible hasta que se pulse una tecla.
        // El contenido es lazy: puede no existir aún en la primera apertura
        // (onLoaded del Loader lo enfoca al completarse).
        syncSysInfoDemand();
        if (visible)
            Qt.callLater(() => contentLoader.item?.focusDefault?.());
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

    // ── Content (lazy) ─────────────────────────────────────────
    // Incluye SysInfoTab (gráficos) + bluetooth/audio: se crea solo al abrir.
    Loader {
        id: contentLoader

        anchors {
            top: bg.top
            left: bg.left
            right: bg.right
            bottom: bg.bottom
        }
        active: root.visible
        asynchronous: false
        sourceComponent: panelComp
        onLoaded: {
            if (root.visible)
                Qt.callLater(() => contentLoader.item?.focusDefault?.());
        }
    }

    Component {
        id: panelComp

        PanelWithControlsContent {
            anchors.fill: parent
            username: root.username
            hostname: root.hostname
            btAdapter: root.btAdapter
            audioSink: root.audioSink
        }
    }
}
