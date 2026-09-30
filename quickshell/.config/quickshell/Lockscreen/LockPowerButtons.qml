// LockPowerButtons — apagar/reiniciar sin desbloquear.
// Extraído de LockScreenContent.qml. Se instancia DENTRO de LockAuthView
// para heredar su visibilidad (solo etapa despierta).
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    anchors.fill: parent

    // Copia local a propósito (ver FileMenu.js): los .js no ven Qt y
    // los componentes no comparten ámbito; misma semántica en todos.
    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }


    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.spacing.l
        spacing: Appearance.spacing.m

        Repeater {
            model: [
                { icon: "power_settings_new", cmd: ["systemctl", "poweroff"], name: "Apagar" },
                { icon: "restart_alt", cmd: ["systemctl", "reboot"], name: "Reiniciar" }
            ]

            delegate: Rectangle {
                required property var modelData

                implicitWidth: 44
                implicitHeight: 44
                radius: Appearance.shape.full
                color: powerMouse.containsMouse ? withAlpha(Appearance.md3.error_container, 0.5) : withAlpha(Appearance.md3.surface_container_high, 0.72)
                border.width: 1
                border.color: withAlpha(Appearance.md3.outline_variant, 0.5)

                Accessible.role: Accessible.Button
                Accessible.name: modelData.name

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: modelData.icon
                    size: 24
                    color: powerMouse.containsMouse ? Appearance.md3.error : Appearance.md3.on_surface_variant
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerProc.start(modelData.cmd)
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
