// --- WallpaperMenu (Wrapper) ---
// Responsabilidades: PanelWindow, IPC, FocusGrab, Shortcut,
// animación del contenedor y enrutamiento de señales.
// NO contiene lógica visual ni layout de contenido.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import qs.Shared.Background
import qs.Panels.Wallpaper.Content

Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    PanelWindow {
        id: wallpaperMenu

        implicitWidth: 800
        implicitHeight: 280
        color: "transparent"
        screen: root.focusedScreen

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: WlrLayershell.Ignore

        // ── Visibilidad: la ventana permanece visible mientras la animación
        //    de salida sigue en curso; la máscara bloquea el input cuando oculta.
        visible: showing || animatedContainer.opacity > 0

        // ── Máscara de input: activa sólo sobre el contenido visible ─────────
        Region { id: emptyRegion }
        Region { id: activeRegion; item: animatedContainer }
        mask: showing ? activeRegion : emptyRegion

        // ── Estado ────────────────────────────────────────────────────────────
        property bool showing: false

        function show() { showing = true }
        function hide() { showing = false }

        // ── Seguir pantalla enfocada ──────────────────────────────────────────
        Connections {
            target: root
            function onFocusedScreenChanged() {
                wallpaperMenu.screen = root.focusedScreen
            }
        }

        // ── FocusGrab: cierra al hacer clic fuera ─────────────────────────────
        HyprlandFocusGrab {
            windows: [wallpaperMenu]
            active: wallpaperMenu.showing
            onCleared: {
                if (wallpaperMenu.showing)
                    Qt.callLater(() => wallpaperMenu.showing = false)
            }
        }

        // ── Foco inicial al abrir ─────────────────────────────────────────────
        onShowingChanged: {
            if (showing) menuContent.requestFocus()
        }

        Shortcut {
            sequence: "Escape"
            onActivated: wallpaperMenu.showing = false
        }

        IpcHandler {
            target: "ui.wallpaperMenu"
            function toggleWallpaperMenu(): void {
                wallpaperMenu.showing = !wallpaperMenu.showing
            }
        }

        // ── Contenedor animado ────────────────────────────────────────────────
        // Toda la animación de entrada/salida vive aquí, no en el Content.
        Item {
            id: animatedContainer
            anchors.fill: parent

            opacity: wallpaperMenu.showing ? 1.0 : 0.0
            scale:   wallpaperMenu.showing ? 1.0 : 0.95
            transformOrigin: Item.Bottom     // crece desde el borde inferior

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // ── Background (forma visual, radio, sombra, borde) ───────────────
            PopupBackground {
                anchors.fill: parent
            }

            // ── Content (layout puro, sin referencias al Wrapper) ─────────────
            WallpaperMenuContent {
                id: menuContent
                anchors.fill: parent
                anchors.margins: 16

                // El Content no sabe nada de "showing"; sólo recibe una señal
                // cuando debe cerrarse y la reenvía hacia arriba.
                onHideRequested: wallpaperMenu.showing = false
            }
        }
    }
}
