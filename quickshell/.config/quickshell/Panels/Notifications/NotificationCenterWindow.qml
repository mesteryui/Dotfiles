import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Core
import qs.Primitives

PanelWindow {
    id: root

    // ── Estado ────────────────────────────────────────────────────────────────
    // "showing" controla la lógica; "visible" se mantiene activo durante la
    // animación de salida para que el fade tenga tiempo de completarse.
    property bool showing: false
    visible: showing || backgroundRect.opacity > 0

    WlrLayershell.namespace: "notifications_center"
    WlrLayershell.layer: WlrLayer.Overlay
    // Necesario para que el Shortcut de Escape reciba eventos de teclado.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: WlrLayershell.Ignore

    // Pantalla completa para interceptar clics en el fondo
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    color: "transparent"

    // ── FocusGrab ─────────────────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.showing
        onCleared: {
            // Qt.callLater obligatorio en onCleared — regla del proyecto.
            if (root.showing)
                Qt.callLater(() => root.showing = false)
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.showing = false
    }

    IpcHandler {
        target: "ui.notifications"
        function toggle(): void { root.showing = !root.showing }
        function show(): void   { root.showing = true }
        function hide(): void   { root.showing = false }
    }

    // ── Fondo oscuro semitransparente ─────────────────────────────────────────
    // El fade aquí sí ocurre porque "visible" de la ventana se mantiene
    // activo mientras opacity > 0.
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Qt.alpha(Appearance.md3.background ?? Appearance.md3.surface, 0.45)

        opacity: root.showing ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.showing = false
        }
    }

    // ── Panel flotante centrado ────────────────────────────────────────────────
    Rectangle {
        id: centerCard
        anchors.centerIn: parent
        width: historyPanel.implicitWidth
        height: historyPanel.implicitHeight
        color: Appearance.md3.surface
        radius: 24

        scale: root.showing ? 1.0 : 0.95
        opacity: root.showing ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // Borde M3
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Appearance.md3.outline_variant
            radius: parent.radius
            z: 10
        }

        // Sombra tonal
        MultiEffect {
            source: centerCard
            anchors.fill: centerCard
            shadowEnabled: true
            shadowColor: Appearance.md3.shadow ?? "#000000"
            shadowOpacity: 0.18
            shadowBlur: 0.8
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
            z: -1
        }

        NotificationHistoryPanel {
            id: historyPanel
            anchors.fill: parent
        }
    }
}
