pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: root

    model: Quickshell.screens

    readonly property var isFloating: ConfigService.configs.bar.barType === "full_hug"

    readonly property var isPartial: ConfigService.configs.bar.barType === "partial_hug"
    delegate: Scope {
        id: screenScope

        required property ShellScreen modelData

        // --- VARIABLES DE CONFIGURACIÓN ---
        property int cornerRadius: 29
        property int borderThickness: 12

        // --- INTERRUPTORES PARA LA BARRA ---
        // Cambia estos valores a 'false' en el lado donde tengas tu barra
        // para que no se dibuje la línea conectora en esa zona.
        property bool drawTopLine: ConfigService.configs.bar.position !== "top"  // Apagado (asumiendo que hay una barra arriba)
        property bool drawBottomLine: ConfigService.configs.bar.position !== "bottom" // Encendido

        // (Opcional) Si tampoco quieres que se dibujen las esquinas redondas
        // donde está la barra, puedes usar estas variables en las esquinas:
        property bool drawTopCorners: true
        property bool drawBottomCorners: true

        // ==========================================
        // 1. ESQUINAS
        // ==========================================
        // Las 4 esquinas comparten el mismo trazado (ver ScreenCorner.qml);
        // solo cambia qué borde/esquina de la pantalla ocupan y su espejo.

        // --- ESQUINA SUPERIOR IZQUIERDA ---
        PanelWindow {
            screen: screenScope.modelData
            anchors {
                top: true
                left: true
            }
            WlrLayershell.namespace: "quickshell:border-left"
            implicitWidth: screenScope.cornerRadius
            implicitHeight: screenScope.cornerRadius
            color: "transparent"
            visible: screenScope.drawTopCorners && root.isFloating || root.isPartial // Se oculta si no quieres esquinas arriba

            ScreenCorner {
                anchors.fill: parent
                cornerRadius: screenScope.cornerRadius
                fillColor: Appearance.md3.surface
            }
        }

        // --- ESQUINA SUPERIOR DERECHA ---
        PanelWindow {
            screen: screenScope.modelData
            anchors {
                top: true
                right: true
            }
            WlrLayershell.namespace: "quickshell:border-right"
            implicitWidth: screenScope.cornerRadius
            implicitHeight: screenScope.cornerRadius
            color: "transparent"
            visible: screenScope.drawTopCorners && root.isFloating || root.isPartial

            ScreenCorner {
                anchors.fill: parent
                cornerRadius: screenScope.cornerRadius
                fillColor: Appearance.md3.surface
                mirrorX: true
            }
        }

        // --- ESQUINA INFERIOR IZQUIERDA ---
        PanelWindow {
            screen: screenScope.modelData
            anchors {
                bottom: true
                left: true
            }
            WlrLayershell.namespace: "quickshell:border-bottom-left"
            implicitWidth: screenScope.cornerRadius
            implicitHeight: screenScope.cornerRadius
            color: "transparent"
            visible: screenScope.drawBottomCorners && root.isFloating

            ScreenCorner {
                anchors.fill: parent
                cornerRadius: screenScope.cornerRadius
                fillColor: Appearance.md3.surface
                mirrorY: true
            }
        }

        // --- ESQUINA INFERIOR DERECHA ---
        PanelWindow {
            screen: screenScope.modelData
            anchors {
                bottom: true
                right: true
            }
            WlrLayershell.namespace: "quickshell:border-bottom-right"
            implicitWidth: screenScope.cornerRadius
            implicitHeight: screenScope.cornerRadius
            color: "transparent"

            visible: screenScope.drawBottomCorners && root.isFloating

            ScreenCorner {
                anchors.fill: parent
                cornerRadius: screenScope.cornerRadius
                fillColor: Appearance.md3.surface
                mirrorX: true
                mirrorY: true
            }
        }

        // ==========================================
        // 2. LÍNEAS CONECTORAS
        // ==========================================

        // --- LÍNEA IZQUIERDA ---
        PanelWindow {
            screen: screenScope.modelData
            WlrLayershell.namespace: "quickshell:connect-left"
            anchors {
                left: true
                top: true
                bottom: true
            }
            implicitWidth: screenScope.borderThickness
            color: "transparent"
            visible: root.isFloating

            Rectangle {
                anchors.fill: parent
                color: Appearance.md3.surface
            }
        }

        // --- LÍNEA DERECHA ---
        PanelWindow {
            screen: screenScope.modelData
            WlrLayershell.namespace: "quickshell:connect-right"
            visible: root.isFloating
            anchors {
                right: true
                top: true
                bottom: true
            }
            implicitWidth: screenScope.borderThickness
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Appearance.md3.surface
            }
        }

        // --- LÍNEA SUPERIOR ---
        PanelWindow {
            WlrLayershell.namespace: "quickshell:connect-top"
            screen: screenScope.modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: screenScope.borderThickness
            color: "transparent"

            // Aquí usamos la variable para mostrar u ocultar la línea
            visible: screenScope.drawTopLine && root.isFloating

            Rectangle {
                anchors.fill: parent
                color: Appearance.md3.surface
            }
        }

        // --- LÍNEA INFERIOR ---
        PanelWindow {
            screen: screenScope.modelData
            WlrLayershell.namespace: "quickshell:connect-down"
            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: screenScope.borderThickness
            color: "transparent"

            // Aquí usamos la variable para mostrar u ocultar la línea
            visible: screenScope.drawBottomLine && root.isFloating

            Rectangle {
                anchors.fill: parent
                color: Appearance.md3.surface
            }
        }
    }
}
