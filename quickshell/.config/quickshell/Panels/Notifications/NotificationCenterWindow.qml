import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Core
import qs.Primitives

PanelWindow {
    id: root
    visible: false

    WlrLayershell.namespace: "notifications_center"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore

    // Pantalla completa para interceptar clics en el fondo
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    color: "transparent"

    // Captura de foco de Hyprland para cerrar al hacer clic fuera
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                root.visible = false;
        }
    }

    // Atajo para cerrar con Escape
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.visible)
                root.visible = false;
        }
    }

    // Manejador de IPC para abrir y cerrar el panel de control
    IpcHandler {
        target: "ui.notifications"
        
        function toggle(): void {
            root.visible = !root.visible;
        }

        function show(): void {
            root.visible = true;
        }

        function hide(): void {
            root.visible = false;
        }
    }

    // Fondo oscuro semitransparente con transición
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.md3.background ?? Colors.md3.surface, 0.45)

        opacity: root.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // Panel de control flotante en el centro
    Rectangle {
        id: centerCard
        anchors.centerIn: parent
        width: historyPanel.implicitWidth
        height: historyPanel.implicitHeight
        color: Colors.md3.surface
        radius: 24

        scale: root.visible ? 1 : 0.95
        opacity: root.visible ? 1 : 0
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; overshoot: 1.1 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // Borde M3
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Colors.md3.outline_variant
            radius: parent.radius
            z: 10
        }

        // Sombra tonal
        MultiEffect {
            source: centerCard
            anchors.fill: centerCard
            shadowEnabled: true
            shadowColor: Colors.md3.shadow ?? "#000000"
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
