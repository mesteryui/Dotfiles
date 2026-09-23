pragma ComponentBehavior: Bound

import qs.Core.Modules
import qs.Shared.Background
import qs.Panels.Wallpaper.Content
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    readonly property int animDuration: 220
    // Fuente única del monitor enfocado (con fallback a la primera pantalla).
    property var focusedScreen: Screens.focusedScreen
    property bool showing: false
    property bool _isAnimatingOut: false

    onShowingChanged: {
        if (root.showing)
            root._isAnimatingOut = false;
        else
            root._isAnimatingOut = true;
    }

    IpcHandler {
        target: "ui.wallpaperMenu"

        function toggleWallpaperMenu(): void {
            root.showing = !root.showing;
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle Wallpaper Selector Carousel"
        onPressed: {
            root.showing = !root.showing;
        }
    }

    PanelWindow {
        id: wallpaperMenu

        implicitWidth: 1120
        implicitHeight: 330 // +52 respecto al original: fila de búsqueda + spacing
        color: "transparent"
        screen: root.focusedScreen
        visible: root.showing || root._isAnimatingOut
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:wallpaper-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

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
                // El contenido es lazy+async: en la primera apertura el item
                // aún no existe aquí; onLoaded lo enfoca al completarse.
                // Si ya existe (reapertura rápida), diferir un frame.
                if (root.showing)
                    Qt.callLater(() => contentLoader.item?.requestFocus?.());
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.showing = false
        }

        Item {
            id: animatedContainer

            anchors.fill: parent

            opacity: 0.0
            scale: 0.92
            transformOrigin: Item.Bottom

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
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            }

            ParallelAnimation {
                id: closeAnim

                OpacityAnimator {
                    target: animatedContainer
                    to: 0.0
                    duration: root.animDuration
                    easing.type: Easing.OutQuad
                }
                ScaleAnimator {
                    target: animatedContainer
                    to: 0.92
                    duration: root.animDuration
                    easing.type: Easing.OutCubic
                }

                onFinished: {
                    if (!root.showing)
                        root._isAnimatingOut = false;
                }
            }

            Component.onCompleted: {
                if (root.showing) {
                    closeAnim.stop();
                    openAnim.start();
                }
            }

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

            Loader {
                id: contentLoader

                anchors.fill: parent
                anchors.margins: 18
                active: root.showing || root._isAnimatingOut
                asynchronous: true
                sourceComponent: menuComp
                onLoaded: {
                    // Carga asíncrona: el foco solo se puede pedir aquí,
                    // cuando el item ya existe y la ventana está visible.
                    if (root.showing)
                        Qt.callLater(() => contentLoader.item?.requestFocus?.());
                }
            }

            Component {
                id: menuComp

                WallpaperMenuContent {
                    anchors.fill: parent
                    onHideRequested: root.showing = false
                }
            }
        }
    }
}
