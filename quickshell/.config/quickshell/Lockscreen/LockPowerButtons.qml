// LockPowerButtons — apagar/reiniciar sin desbloquear.
// Extraído de LockScreenContent.qml. Se instancia DENTRO de LockAuthView
// para heredar su visibilidad (solo etapa despierta).
pragma ComponentBehavior: Bound

import qs.Core
import qs.Primitives
import QtQuick
import Quickshell.Io

Item {
    id: root

    anchors.fill: parent

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.spacing.large
        spacing: Appearance.spacing.medium

        Repeater {
            model: [
                {
                    icon: "power_settings_new",
                    cmd: ["systemctl", "poweroff"],
                    name: "Apagar"
                },
                {
                    icon: "restart_alt",
                    cmd: ["systemctl", "reboot"],
                    name: "Reiniciar"
                }
            ]

            delegate: Rectangle {
                id: powerDelegate

                required property var modelData

                implicitWidth: 44
                implicitHeight: 44
                radius: Appearance.shape.full
                color: powerMouse.containsMouse ? Qt.alpha(Appearance.md3.error_container, 0.5) : Qt.alpha(
                                                      Appearance.md3.surface_container_high, 0.72)
                border.width: Appearance.border.width
                border.color: Appearance.border.subtleOn(color)

                Accessible.role: Accessible.Button
                Accessible.name: modelData.name

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: powerDelegate.modelData.icon
                    size: 24
                    color: powerMouse.containsMouse ? Appearance.md3.error : Appearance.md3.on_surface_variant
                }

                MouseArea {
                    id: powerMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerProc.start(powerDelegate.modelData.cmd)
                }

                Process {
                    id: powerProc

                    function start(cmd) {
                        powerProc.command = cmd;
                        powerProc.running = true;
                    }
                }
            }
        }
    }
}
