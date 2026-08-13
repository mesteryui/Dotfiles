// --- WallpaperMenu (Wrapper) ---
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import qs.Shared.Background
import qs.Panels.Wallpaper.Content

Scope {
    id: root

    property var focusedScreen: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) ? (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name) ?? null) : null
    property bool showing: false
    property bool _isAnimatingOut: false

    // ── Timer de seguridad: Garantiza que la capa se destruya en Wayland ──
    // Evita que un fallo en la animación deje el componente vivo eternamente.
    Timer {
        id: closeTimer
        interval: 200 // Debe coincidir exactamente con la duración de la animación
        running: false
        onTriggered: {
            root._isAnimatingOut = false; // Apaga el Loader y purga la layer de Hyprland
        }
    }

    // Gestionar el cambio de estado de apertura/cierre de forma limpia
    onShowingChanged: {
        if (root.showing) {
            closeTimer.stop();
            root._isAnimatingOut = false;
        } else {
            root._isAnimatingOut = true;
            closeTimer.restart(); // Dispara el tiempo de gracia para la animación de salida
        }
    }

    // El IPC vive siempre activo en la raíz
    IpcHandler {
        target: "ui.wallpaperMenu"
        function toggleWallpaperMenu(): void {
            root.showing = !root.showing;
        }
    }

    Loader {
        id: wallpaperSelectorLoader
        // El Loader se mantiene vivo si se está mostrando O si está corriendo el tiempo de salida
        active: root.showing || root._isAnimatingOut

        sourceComponent: PanelWindow {
            id: wallpaperMenu

            implicitWidth: 800
            implicitHeight: 280
            color: "transparent"
            screen: root.focusedScreen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:wallpaper-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore

            visible: true

            /*Region { id: emptyRegion }
            Region { id: activeRegion; item: animatedContainer }
            mask: root.showing ? activeRegion : emptyRegion*/

            Connections {
                target: root
                function onFocusedScreenChanged() {
                    wallpaperMenu.screen = root.focusedScreen;
                }
            }

            HyprlandFocusGrab {
                windows: [wallpaperMenu]
                active: root.showing
                onCleared: {
                    if (root.showing)
                        Qt.callLater(() => root.showing = false);
                }
            }

            Connections {
                target: root
                function onShowingChanged() {
                    if (root.showing)
                        menuContent.requestFocus();
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.showing = false
            }

            // ── Contenedor animado ────────────────────────────────────────────────
            Item {
                id: animatedContainer
                anchors.fill: parent

                opacity: root.showing ? 1.0 : 0.0
                scale: root.showing ? 1.0 : 0.95
                transformOrigin: Item.Bottom

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                PopupBackground {
                    anchors.fill: parent
                }

                WallpaperMenuContent {
                    id: menuContent
                    anchors.fill: parent
                    anchors.margins: 16
                    onHideRequested: root.showing = false
                }
            }
        }
    }
}