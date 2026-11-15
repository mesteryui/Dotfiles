pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Modules
import qs.Panels.Wallpaper.Content
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    readonly property int animDuration: 200
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

    LazyLoader {
        loading: root.showing || root._isAnimatingOut

        component: PanelWindow {
            id: wallpaperMenu

            color: "transparent"
            screen: root.focusedScreen
            visible: root.showing || root._isAnimatingOut
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:wallpaper-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                left: true
                right: true
                bottom: true
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
                        Qt.callLater(() => contentLoader.item?.requestFocus?.());
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    const content = contentLoader.item;
                    if (!content || !content.escapePressed || !content.escapePressed())
                        root.showing = false;
                }
            }

            // Fondo semitransparente con opacidad exacta de 0.5 fuera de la lista y la barra superior
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: animatedContainer.opacity * 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                id: animatedContainer

                anchors.fill: parent

                opacity: 0.0
                scale: 0.94
                transformOrigin: Item.Center

                ParallelAnimation {
                    id: openAnim

                    OpacityAnimator {
                        target: animatedContainer
                        to: 1.0
                        duration: root.animDuration
                        easing.type: Easing.OutCubic
                    }
                    SpringAnimation {
                        target: animatedContainer
                        property: "scale"
                        to: 1.0
                        spring: 2.6
                        damping: 0.18
                        mass: 0.8
                        epsilon: 0.003
                    }
                }

                ParallelAnimation {
                    id: closeAnim

                    OpacityAnimator {
                        target: animatedContainer
                        to: 0.0
                        duration: root.animDuration
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Appearance.motion.standard
                    }
                    SpringAnimation {
                        target: animatedContainer
                        property: "scale"
                        to: 0.94
                        spring: 4.0
                        damping: 0.38
                        mass: 0.8
                        epsilon: 0.003
                    }

                    onFinished: {
                        if (!root.showing)
                            root._isAnimatingOut = false;
                    }
                }

                function playOpen() {
                    closeAnim.stop();
                    openAnim.start();
                }

                Component.onCompleted: {
                    if (root.showing)
                        animatedContainer.playOpen();
                }

                Connections {
                    target: root

                    function onShowingChanged() {
                        if (root.showing) {
                            animatedContainer.playOpen();
                        } else {
                            openAnim.stop();
                            closeAnim.start();
                        }
                    }
                }

                Loader {
                    id: contentLoader

                    anchors.fill: parent
                    active: root.showing || root._isAnimatingOut
                    asynchronous: true
                    sourceComponent: menuComp
                    onLoaded: {
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
}
