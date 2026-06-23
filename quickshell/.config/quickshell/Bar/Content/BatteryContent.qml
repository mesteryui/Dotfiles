import QtQuick
import qs.Primitives
import qs.Core
import qs.Core.Services as Services
Item {
    id: root
    implicitWidth: layout.childrenRect.width + 5
    implicitHeight: 30

    Row {
        id: layout
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter
        MaterialIcon {
            id: batteryIcon
            size: 20
            color: Colors.md3.on_surface
            anchors.verticalCenter: parent.verticalCenter
            icon: Services.BatteryService.materialIcon
        }

        StyledText {
            // Mostramos el porcentaje redondeado
            anchors.verticalCenter: parent.verticalCenter
            text: Services.BatteryService.percentage + "%";
            color: Colors.md3.on_surface
        }
    }
}