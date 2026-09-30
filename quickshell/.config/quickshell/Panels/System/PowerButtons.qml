pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import M3Shapes

// --- PowerButtons ---
// Overlay fullscreen de menú de apagado. Extiende PanelWindow directamente
// (no MenuWindow) porque necesita cubrir toda la pantalla, no un panel pequeño.
Scope {
    id: root

    property bool show: false
    property bool animating: false

    IpcHandler {
        target: "ui.powermenu"

        function togglePowerMenu(): void {
            root.show = !root.show;
        }
    }

    Timer {
        id: animatingTimer

        interval: 200
        onTriggered: root.animating = false
        running: false
    }
    // LazyLoader: el overlay se incuba en background y se cachea. Como ya
    // no se destruye al cerrarse, el visible de la ventana va atado a show.
    LazyLoader {
        id: loader

        loading: root.show
        component: PanelWindow {
            id: powerButtons

            visible: root.show

            WlrLayershell.namespace: "quickshell:logout_dialog"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            // Fullscreen: anclar los 4 lados
            anchors.left: true
            anchors.right: true
            anchors.top: true
            anchors.bottom: true

            color: "transparent"

            HyprlandFocusGrab {
                windows: [powerButtons]
                active: root.show
                onCleared: {
                   if (root.show) {
                        root.animating = true
                        animatingTimer.running = true
                        root.show = false;
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (root.show) {
                        root.animating = true
                        animatingTimer.running = true
                        root.show = false;

                    }

                }
            }

            onVisibleChanged: {
                if (visible)
                    shutdownBtn.forceActiveFocus();
                root.show = visible
            }

            // Scrim M3 (spec diálogos): velo scrim al 32%.
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Appearance.md3.scrim, 0.32)

                opacity: root.show ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Appearance.motion.emphasized
                    }
                }
            }

            // Tarjeta centrada con los botones
            Rectangle {
                anchors.centerIn: parent
                width: powerButtonsLayout.implicitWidth + 48
                height: powerButtonsLayout.implicitHeight + 48
                color: Appearance.md3.surface
                radius: Appearance.shape.verylarge

                scale: root.show ? 1 : 0.94
                opacity: root.show ? 1 : 0

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.motion.short4
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.motion.short4
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Appearance.motion.emphasized
                    }
                }

                // Borde M3
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Appearance.md3.outline_variant
                    radius: parent.radius
                    z: 10
                }

                RowLayout {
                    id: powerButtonsLayout

                    anchors.centerIn: parent
                    spacing: 20

                    PowerButton {
                        id: shutdownBtn

                        buttonText: Services.I18nService.getTranslation("power.shutdown")
                        buttonIcon: "power_settings_new"
                        buttonShape: MaterialShape.Circle
                        accentColor: Appearance.md3.error
                        command: "systemctl poweroff"
                        KeyNavigation.left: logoutBtn
                        KeyNavigation.right: rebootBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: rebootBtn

                        buttonText: Services.I18nService.getTranslation("power.reboot")
                        buttonIcon: "restart_alt"
                        buttonShape: MaterialShape.Cookie6Sided
                        command: "systemctl reboot"
                        KeyNavigation.left: shutdownBtn
                        KeyNavigation.right: suspendBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: suspendBtn

                        buttonText: Services.I18nService.getTranslation("power.suspend")
                        buttonIcon: "bedtime"
                        buttonShape: MaterialShape.ClamShell
                        command: "systemctl suspend"
                        KeyNavigation.left: rebootBtn
                        KeyNavigation.right: lockBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: lockBtn

                        buttonText: Services.I18nService.getTranslation("power.lock")
                        buttonIcon: "lock"
                        buttonShape: MaterialShape.Diamond
                        command: "qs ipc call lockscreen lock"
                        KeyNavigation.left: suspendBtn
                        KeyNavigation.right: logoutBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: logoutBtn

                        buttonText: Services.I18nService.getTranslation("power.logout")
                        buttonIcon: "logout"
                        buttonShape: MaterialShape.Arrow
                        command: "hyprctl dispatch 'hl.dsp.exit()'"
                        KeyNavigation.left: lockBtn
                        KeyNavigation.right: shutdownBtn
                        Layout.alignment: Qt.AlignCenter
                    }
                }
            }
        }

    // El morph al resaltar lo gestiona GenericButton (reposo Circle,
    // resaltado con forma-identidad); aquí solo se fija la identidad
    // de cada acción vía buttonShape.
    component PowerButton: GenericButton {
    }
}}
