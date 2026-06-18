import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Services.UPower
import qs.Core
import qs.Components
import qs.Core.Services as Services
import Quickshell.Wayland

BaseOSD {
    id: batteryOSD
    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20
    property string osdIcon: "battery_full"
    property string osdText

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged(): void {
            if (UPower.displayDevice.state === UPowerDeviceState.Discharging) {
                const rounded_percentage = Math.round(UPower.displayDevice.percentage * 100);
                if (rounded_percentage === 20 || rounded_percentage === 10) {
                    batteryOSD.osdIcon = rounded_percentage === 10 ? "battery_alert" : "battery_low";
                    if (rounded_percentage === 10) {
                        batteryOSD.osdText = Services.I18nService.getTranslation("battery.critical", "¡Batería crítica (%1%)! Conecta el cargador de inmediato").arg(rounded_percentage);
                    } else {
                        batteryOSD.osdText = Services.I18nService.getTranslation("battery.low", "Batería baja (%1%): Te recomendamos cargar el equipo").arg(rounded_percentage);
                    }
                    batteryOSD.show()
                }
            }
        }
        function onStateChanged(): void {
            if (UPower.displayDevice.state === UPowerDeviceState.Charging) {
                batteryOSD.osdIcon = "battery_charging_full";
                batteryOSD.osdText = Services.I18nService.getTranslation("battery.charging", "Cargando batería");
                batteryOSD.show();
            }
        }
    }
    Rectangle {
        color: Colors.md3.surface
        radius: 30
        anchors.fill: parent
        anchors.centerIn: parent
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 10
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: batteryOSD.osdIcon
                size: 30
                color: Colors.md3.on_surface
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 26
                color: Colors.md3.on_surface
                text: batteryOSD.osdText
            }
        }
    }
}
