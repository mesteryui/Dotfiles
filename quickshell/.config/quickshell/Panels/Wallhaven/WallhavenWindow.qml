// --- Wallhaven: buscar y descargar fondos de wallhaven.cc ---
pragma ComponentBehavior: Bound

import qs.Core.Modules
import qs.Shared.Background
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool showing: false
    // Fuente única del monitor enfocado (con fallback a la primera pantalla).
    property var focusedScreen: Screens.focusedScreen

    IpcHandler {
        target: "ui.wallhaven"

        function toggleWallhaven(): void {
            root.showing = !root.showing;
        }
    }

    GlobalShortcut {
        name: "wallhavenToggle"
        description: "Toggle Wallhaven"
        onPressed: {
            root.showing = !root.showing;
        }
    }

    PanelWindow {
        id: wallhavenWindow

        implicitWidth: 1020
        implicitHeight: 660
        color: "transparent"
        screen: root.focusedScreen
        visible: root.showing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:wallhaven"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

        HyprlandFocusGrab {
            windows: [wallhavenWindow]
            active: root.showing
            onCleared: {
                if (root.showing)
                    Qt.callLater(() => root.showing = false);
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.showing = false
        }

        PopupBackground {
            anchors.fill: parent
        }

        // Contenido lazy+async: la ventana pasa oculta casi siempre
        // (mismo patrón que WallpaperMenu).
        Loader {
            anchors.fill: parent
            active: root.showing
            asynchronous: true
            sourceComponent: wallhavenComp
        }

        Component {
            id: wallhavenComp

            WallhavenWindowContent {
                anchors.fill: parent
            }
        }
    }
}
