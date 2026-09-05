import qs.Core
import qs.Primitives
import qs.Core.Services as Services
import qs.Shared.Background
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

IconTextOSD {
    id: batteryOSD

    type: "battery"

    osdIcon: "battery_full"
    osdText: ""

    Connections {
        target: Services.BatteryService.displayDevice

        function onPercentageChanged(): void {
            if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Discharging) {
                const pct = Services.BatteryService.percentage;
                if (pct === 20 || pct === 10) {
                    batteryOSD.osdIcon = pct === 10 ? "battery_alert" : "battery_low";
                    batteryOSD.osdText = pct === 10 ? Services.I18nService.getTranslation("battery.critical", "¡Batería crítica (%1%)! Conecta el cargador de inmediato").arg(pct) : Services.I18nService.getTranslation("battery.low", "Batería baja (%1%): Te recomendamos cargar el equipo").arg(pct);
                    batteryOSD.show();
                }
            }
        }

        // BUG #5 FIX: onStateChanged estaba FUERA del bloque Connections
        // (la llave de cierre anterior lo dejaba huérfano como función del Scope).
        // Al moverlo aquí dentro, Quickshell lo conecta correctamente a la señal
        // stateChanged del displayDevice.
        function onStateChanged(): void {
            if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Charging) {
                batteryOSD.osdIcon = "battery_charging_full";
                batteryOSD.osdText = Services.I18nService.getTranslation("battery.charging", "Cargando batería");
                batteryOSD.show();
            }
        }
    }
}
