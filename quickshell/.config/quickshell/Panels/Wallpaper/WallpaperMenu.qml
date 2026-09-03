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

    readonly property int animDuration: 220
    property var focusedScreen: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) ? (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name) ?? null) : null
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

            WallpaperMenuContent {
                id: menuContent
                anchors.fill: parent
                anchors.margins: 18
                onHideRequested: root.showing = false
            }
        }
    }
}
