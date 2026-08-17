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

    readonly property int animDuration: 200
    property var focusedScreen: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) ? (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name) ?? null) : null
    property bool showing: false
    property bool _isAnimatingOut: false

    // Gestionar el cambio de estado de apertura/cierre de forma limpia.
    // El apagado real del Loader ya NO depende de un Timer con un número
    // mágico duplicado: se dispara desde el onFinished del OpacityAnimator
    // de animatedContainer, así el cierre de la layer sigue a la animación
    // de verdad en vez de a una estimación de su duración.
    onShowingChanged: {
        if (root.showing)
            root._isAnimatingOut = false;
        else
            root._isAnimatingOut = true;
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

            implicitWidth: 1000
            implicitHeight: 270
            color: "transparent"
            screen: root.focusedScreen // binding declarativo: se actualiza solo al cambiar el foco

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:wallpaper-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore

            /*Region {
                id: emptyRegion
            }
            Region {
                id: activeRegion
                item: animatedContainer
            }
            mask: root.showing ? activeRegion : emptyRegion*/

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

            Item {
                id: animatedContainer
                anchors.fill: parent

                // Estado inicial para que no aparezca de golpe antes de animar
                opacity: 0.0
                scale: 0.95
                transformOrigin: Item.Bottom

                // Animación de entrada con Animators (Render Thread)
                ParallelAnimation {
                    id: openAnim
                    OpacityAnimator {
                        target: animatedContainer
                        to: 1.0
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                    ScaleAnimator {
                        target: animatedContainer
                        to: 1.0
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                // Animación de salida con Animators
                ParallelAnimation {
                    id: closeAnim
                    OpacityAnimator {
                        target: animatedContainer
                        to: 0.0
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                    ScaleAnimator {
                        target: animatedContainer
                        to: 0.95
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                    onFinished: {
                        if (!root.showing)
                            root._isAnimatingOut = false;
                    }
                }

                // Al crearse la ventana dentro del Loader, arranca la animación de apertura
                Component.onCompleted: {
                    if (root.showing) {
                        closeAnim.stop();
                        openAnim.start();
                    }
                }

                // Gestionar alternancias de apertura y cierre mientras el Loader siga cargado
                Connections {
                    target: root
                    function onShowingChanged() {
                        if (root.showing) {
                            closeAnim.stop();
                            openAnim.start();
                        } else {
                            openAnim.stop();
                            closeAnim.start();
                        }
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
