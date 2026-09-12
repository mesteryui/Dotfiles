pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: root

    model: Quickshell.screens

    // Propiedad visual puente: dictamina el estado actual
    readonly property string activeBarType: GameMode.enabled ? "no_floating" : ConfigService.configs.bar.barType

    // Ahora derivan del estado puente, respetando el Modo Juego
    readonly property bool isFloating: activeBarType === "full_hug"
    readonly property bool isPartial: activeBarType === "partial_hug"

    delegate: Scope {
        id: screenScope

        required property ShellScreen modelData

        // --- VARIABLES DE CONFIGURACIÓN ---
        property int cornerRadius: 20
        property int borderThickness: 10

        // --- INTERRUPTORES PARA LA BARRA ---
        property bool drawTopLine: ConfigService.configs.bar.position !== "top"
        property bool drawBottomLine: ConfigService.configs.bar.position !== "bottom"

        property bool drawTopCorners: true
        property bool drawBottomCorners: true

        // ==========================================
        // 1. ESQUINAS
        // ==========================================

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
            // full_hug: siempre. partial_hug: solo si la barra está arriba. no_floating: nunca.
            visible: screenScope.drawTopCorners && (root.isFloating || (root.isPartial && ConfigService.configs.bar.position === "top"))

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
            visible: screenScope.drawTopCorners && (root.isFloating || (root.isPartial && ConfigService.configs.bar.position === "top"))

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
            // full_hug: siempre. partial_hug: solo si la barra está abajo. no_floating: nunca.
            visible: screenScope.drawBottomCorners && (root.isFloating || (root.isPartial && ConfigService.configs.bar.position === "bottom"))

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
            visible: screenScope.drawBottomCorners && (root.isFloating || (root.isPartial && ConfigService.configs.bar.position === "bottom"))

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
            visible: screenScope.drawBottomLine && root.isFloating

            Rectangle {
                anchors.fill: parent
                color: Appearance.md3.surface
            }
        }
    }
}
