import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import ".."
import "../Services" as Services

BarItem {
    id: root
    
    Row {
        anchors.centerIn: parent
        spacing: 6
        IconImage {
            id: batteryIcon
            width: 20
            height: 20
            // Usamos displayDevice para obtener el icono correcto del sistema
            source: {
                const name = UPower.displayDevice?.iconName;
                return (name && name.length > 0) ? Quickshell.iconPath(name) : Quickshell.iconPath("battery-missing");
            }
        }
        Text {
            // Mostramos el porcentaje redondeado
            font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
            text: {
                const p = UPower.displayDevice?.percentage ?? 0;
                return Math.round(p * 100) + "%";
            }
            color: Colors.on_surface_variant
            verticalAlignment: Text.AlignVCenter
        }
    }
}
