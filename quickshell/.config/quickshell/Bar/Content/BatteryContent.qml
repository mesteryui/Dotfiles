import QtQuick
import qs.Components
import qs.Core
import qs.Core.Services as Services
Item {
    id: root
    implicitWidth: layout.childrenRect.width
    implicitHeight: 30

    Row {
        id: layout
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        MaterialIcon {
            id: batteryIcon
            size: 20
            color: Colors.md3.on_surface
            anchors.verticalCenter: parent.verticalCenter
            icon: Services.BatteryService.materialIcon
        }

        Text {
            // Mostramos el porcentaje redondeado
            anchors.verticalCenter: parent.verticalCenter
            font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
            text: Services.BatteryService.percentage + "%";
            color: Colors.md3.on_surface
            verticalAlignment: Text.AlignVCenter
        }
    }
}