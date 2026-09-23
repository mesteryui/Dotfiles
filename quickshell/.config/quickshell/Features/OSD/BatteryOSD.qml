import qs.Core.Services as Services
import QtQuick
import Quickshell.Services.UPower
import M3Shapes

IconTextOSD {
    id: batteryOSD

    type: "battery"

    osdIcon: "battery_full"
    osdText: ""
    // Identidad de forma por nivel: Circle(llena) → Bun(baja) → Boom(crítica).
    property int iconShape: MaterialShape.Circle

    // Igual que VolumeOSD/MicOSD: suprime el spam de UPower durante el arranque,
    // que es cuando I18nService aún sirve en_US y el OSD cachearía inglés.
    property bool ready: false
    // Último estado visto, para retraducir si cambia el idioma con texto cacheado.
    property int lastPct: -1
    property bool lastCharging: false

    Timer {
        id: readyTimer

        interval: 2000
        running: true
        repeat: false
        onTriggered: batteryOSD.ready = true
    }

    function refreshText(): void {
        if (batteryOSD.lastCharging) {
            batteryOSD.osdIcon = "battery_charging_full";
            batteryOSD.osdText = Services.I18nService.getTranslation("battery.charging", "Cargando batería");
            batteryOSD.iconShape = MaterialShape.Circle;
        } else if (batteryOSD.lastPct === 10) {
            batteryOSD.osdIcon = "battery_alert";
            batteryOSD.osdText = Services.I18nService.getTranslation("battery.critical", "¡Batería crítica (%1%)! Conecta el cargador de inmediato").arg(batteryOSD.lastPct);
            batteryOSD.iconShape = MaterialShape.SemiCircle;
            batteryOSD.alert = true;
        } else if (batteryOSD.lastPct === 20) {
            batteryOSD.osdIcon = "battery_low";
            batteryOSD.osdText = Services.I18nService.getTranslation("battery.low", "Batería baja (%1%): Te recomendamos cargar el equipo").arg(batteryOSD.lastPct);
            batteryOSD.iconShape = MaterialShape.Bun;
            batteryOSD.alert = false;
        } else {
            batteryOSD.osdText = Math.round(batteryOSD.lastPct) + "%";
            batteryOSD.iconShape = MaterialShape.Circle;
            batteryOSD.alert = false;
        }
    }

    Connections {
        target: Services.BatteryService.displayDevice

        function onPercentageChanged(): void {
            if (!batteryOSD.ready)
                return;
            if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Discharging) {
                const pct = Services.BatteryService.percentage;
                if (pct === 20 || pct === 10) {
                    batteryOSD.lastPct = pct;
                    batteryOSD.lastCharging = false;
                    batteryOSD.refreshText();
                    batteryOSD.show();
                }
            }
        }

        // BUG #5 FIX: onStateChanged estaba FUERA del bloque Connections
        // (la llave de cierre anterior lo dejaba huérfano como función del Scope).
        // Al moverlo aquí dentro, Quickshell lo conecta correctamente a la señal
        // stateChanged del displayDevice.
        function onStateChanged(): void {
            if (!batteryOSD.ready)
                return;
            if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Charging) {
                batteryOSD.lastCharging = true;
                batteryOSD.refreshText();
                batteryOSD.show();
            } else if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Discharging) {
                batteryOSD.lastCharging = false;
            }
        }
    }

    // Si el idioma cambia después (auto → es_ES tras el arranque),
    // retraduce el último estado en vez de dejar inglés cacheado.
    Connections {
        target: Services.I18nService
        ignoreUnknownSignals: true

        function onLanguageChanged(): void {
            if (batteryOSD.lastPct !== -1 || batteryOSD.lastCharging)
                batteryOSD.refreshText();
        }
    }
}
