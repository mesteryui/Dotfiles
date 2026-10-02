pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

/**
 * Cheatsheet (Scope ligero + LazyLoader interno).
 * El IpcHandler/GlobalShortcut y el hideTimer viven en el scope para
 * responder antes de cargar; la PanelWindow fullscreen solo se instancia
 * al abrir. El fade-out se conserva: el loader sigue activo mientras
 * hideTimer corre, aunque active ya sea false.
 */
Scope {
    id: scope

    property bool active: false
    readonly property int hideAnimDuration: 160

    /// `true` mientras la hoja debe estar visible (abierta o en fade-out).
    readonly property bool isVisible: active || hideTimer.running

    Timer {
        id: hideTimer

        interval: scope.hideAnimDuration
    }

    onActiveChanged: {
        if (!active)
            hideTimer.restart();
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            scope.active = !scope.active;
        }

        function show(): void {
            scope.active = true;
        }

        function hide(): void {
            scope.active = false;
        }
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle the cheatsheet"
        onPressed: {
            scope.active = !scope.active;
        }
    }

    LazyLoader {
        id: cheatsheetLoader
        loading: scope.isVisible

        component: PanelWindow {
            id: root

            readonly property int hideAnimDuration: scope.hideAnimDuration

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            visible: scope.isVisible

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:cheatsheet"
            WlrLayershell.keyboardFocus: scope.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // El estado vive en el scope: se observa con Connections (el
            // item ya no tiene propiedad 'active' propia). En la primera
            // apertura el contenido aún no existe (onLoaded lo resetea).
            Connections {
                target: scope

                function onActiveChanged() {
                    if (scope.active)
                        sheetLoader.item?.resetOnOpen();
                }
            }

            // --- Scrim ---
            Rectangle {
                id: scrim

                anchors.fill: parent
                color: Appearance.md3.shadow
                opacity: scope.isVisible ? 0.55 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.hideAnimDuration
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: scope.active = false
                }
            }

            // --- Content (lazy) ---
            // La hoja es pesada (Repeaters + filtrado) y pasa oculta casi siempre:
            // se crea al abrir y se destruye al terminar el fade-out.
            Loader {
                id: sheetLoader

                anchors.fill: parent
                active: scope.isVisible
                sourceComponent: sheetComp
                onLoaded: {
                    if (scope.active)
                        item.resetOnOpen();
                }
            }

            Component {
                id: sheetComp

                CheatsheetSheet {
                    anchors.fill: parent
                    active: scope.active
                    hideAnimDuration: root.hideAnimDuration
                    onCloseRequested: scope.active = false
                }
            }
        }
    }
}
