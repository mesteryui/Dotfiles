import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import "../../Core"
import "../../Core/Services" as Services
import "../../Components"

BarItem {
    id: root

    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])
    
    Row {
        anchors.centerIn: parent
        spacing: 6
        
        MaterialIcon {
            id: batteryIcon
            size: 20
            color: Colors.md3.on_surface_variant
            
            icon: {
                const device = UPower.displayDevice;
                if (!device) return "battery_unknown";
                
                const p = device.percentage;
                const isCharging = device.state === UPowerDeviceState.Charging;
                
                if (isCharging) {
                    if (p > 0.9) return "battery_charging_full";
                    if (p > 0.75) return "battery_charging_80";
                    if (p > 0.55) return "battery_charging_60";
                    if (p > 0.4) return "battery_charging_50";
                    if (p > 0.25) return "battery_charging_30";
                    return "battery_charging_20";
                }
                
                if (p > 0.9) return "battery_full";
                if (p > 0.7) return "battery_6_bar";
                if (p > 0.5) return "battery_4_bar";
                if (p > 0.3) return "battery_3_bar";
                if (p > 0.15) return "battery_1_bar";
                return "battery_0_bar";
            }
        }
        
        Text {
            // Mostramos el porcentaje redondeado
            anchors.verticalCenter: parent.verticalCenter
            font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
            text: {
                const p = UPower.displayDevice?.percentage ?? 0;
                return Math.round(p * 100) + "%";
            }
            color: Colors.md3.on_surface
            verticalAlignment: Text.AlignVCenter
        }
    }
}
