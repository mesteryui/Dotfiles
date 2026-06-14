import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Services.UPower
import ".."
import Quickshell.Wayland

BaseOSD {
    id: batteryOSD
    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20
    property string osdIcon
    property string osdText

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged(): void {
            if (UPower.displayDevice.state === UPowerDeviceState.Discharging) {
                const rounded_percentage = Math.round(UPower.displayDevice.percentage * 100);
                if (rounded_percentage === 20 || rounded_percentage === 10) {
                    batteryOSD.osdIcon = rounded_percentage === 10 ? "battery-caution-symbolic" : "battery-low-symbolic";
                    if (rounded_percentage === 10) {
                        batteryOSD.osdText = "¡Batería crítica (" + rounded_percentage + "%)! Conecta el cargador de inmediato";
                    } else {
                        batteryOSD.osdText = "Batería baja (" + rounded_percentage + "%): Te recomendamos cargar el equipo";
                    }
                    batteryOSD.visible = true;
                }
            }
        }
        function onStateChanged(): void {
            if (UPower.displayDevice.state === UPowerDeviceState.Charging) {
                batteryOSD.osdIcon = "battery-good-charging-symbolic";
                batteryOSD.osdText = "Cargando bateria";
                batteryOSD.visible = true;
            }
        }
    }
    Rectangle {
        color: Colors.surface
        radius: 30
        anchors.fill: parent
        anchors.centerIn: parent
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 10
            IconImage {
                width: 30
                height: 30
                source: batteryOSD.osdIcon ? Quickshell.iconPath(batteryOSD.osdIcon) : ""
            }
            Text {
                font.pixelSize: 26
                color: Colors.on_surface
                text: batteryOSD.osdText
            }
        }
    }
}
