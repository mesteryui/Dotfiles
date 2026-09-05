pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

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
    Loader {
        id: loader

        active: root.show
        sourceComponent: PanelWindow {
            id: powerButtons

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

            // Fondo oscuro semitransparente que cubre toda la ventana
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Appearance.md3.surface, 0.6)

                opacity: root.show ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // Tarjeta centrada con los botones
            Rectangle {
                anchors.centerIn: parent
                width: powerButtonsLayout.implicitWidth + 48
                height: powerButtonsLayout.implicitHeight + 48
                color: Appearance.md3.surface
                radius: 28

                scale: root.show ? 1 : 0.94
                opacity: root.show ? 1 : 0

                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
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
                        command: "systemctl poweroff"
                        KeyNavigation.left: logoutBtn
                        KeyNavigation.right: rebootBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: rebootBtn

                        buttonText: Services.I18nService.getTranslation("power.reboot")
                        buttonIcon: "restart_alt"
                        command: "systemctl reboot"
                        KeyNavigation.left: shutdownBtn
                        KeyNavigation.right: suspendBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: suspendBtn

                        buttonText: Services.I18nService.getTranslation("power.suspend")
                        buttonIcon: "bedtime"
                        command: "systemctl suspend"
                        KeyNavigation.left: rebootBtn
                        KeyNavigation.right: lockBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: lockBtn

                        buttonText: Services.I18nService.getTranslation("power.lock")
                        buttonIcon: "lock"
                        command: "qs ipc call lockscreen lock"
                        KeyNavigation.left: suspendBtn
                        KeyNavigation.right: logoutBtn
                        Layout.alignment: Qt.AlignCenter
                    }

                    PowerButton {
                        id: logoutBtn

                        buttonText: Services.I18nService.getTranslation("power.logout")
                        buttonIcon: "logout"
                        command: "hyprctl dispatch 'hl.dsp.exit()'"
                        KeyNavigation.left: lockBtn
                        KeyNavigation.right: shutdownBtn
                        Layout.alignment: Qt.AlignCenter
                    }
                }
            }
        }
    }

    component PowerButton: GenericButton {
        property int targetRadiusFocused: 50
        property int targetRadiusUnfocused: 20

        radius: activeFocus ? targetRadiusFocused : targetRadiusUnfocused

        Behavior on radius {
            NumberAnimation {
                duration: 250
                easing.type: Easing.Bezier
                easing.overshoot: 1.5
            }
        }
    }
}
