import QtQuick
import Quickshell.Services.UPower
import qs.Core
import qs.Primitives
import qs.Core.Services as Services
import qs.Shared.Background

BaseOSD {
    id: batteryOSD

    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20

    property string osdIcon: "battery_full"
    property string osdText: ""

    Connections {
        target: Services.BatteryService.displayDevice

        function onPercentageChanged(): void {
            if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Discharging) {
                const pct = Services.BatteryService.percentage
                if (pct === 20 || pct === 10) {
                    batteryOSD.osdIcon = pct === 10 ? "battery_alert" : "battery_low"
                    batteryOSD.osdText = pct === 10
                        ? Services.I18nService.getTranslation(
                            "battery.critical",
                            "¡Batería crítica (%1%)! Conecta el cargador de inmediato"
                          ).arg(pct)
                        : Services.I18nService.getTranslation(
                            "battery.low",
                            "Batería baja (%1%): Te recomendamos cargar el equipo"
                          ).arg(pct)
                    batteryOSD.show()
                }
            }
        }

        // BUG #5 FIX: onStateChanged estaba FUERA del bloque Connections
        // (la llave de cierre anterior lo dejaba huérfano como función del Scope).
        // Al moverlo aquí dentro, Quickshell lo conecta correctamente a la señal
        // stateChanged del displayDevice.
        function onStateChanged(): void {
            if (Services.BatteryService.displayDevice.state === UPowerDeviceState.Charging) {
                batteryOSD.osdIcon = "battery_charging_full"
                batteryOSD.osdText = Services.I18nService.getTranslation(
                    "battery.charging",
                    "Cargando batería"
                )
                batteryOSD.show()
            }
        }
    }

    // BUG #6 FIX: eliminar anchors.centerIn (conflicto con anchors.fill).
    // anchors.fill ya posiciona y dimensiona el componente correctamente.
    PopupBackground {
        anchors.fill: parent
        color: Colors.md3.surface
        radius: 30
    }

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

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 26
            color: Colors.md3.on_surface
            text: batteryOSD.osdText
        }
    }
}
