import qs.Primitives
import qs.Core
import qs.Core.Services as Services
import QtQuick
import QtQuick.Layouts // Importación necesaria para layouts

Item {
    id: root
    // El root ahora simplemente expone el tamaño que el layout determine

    implicitWidth: layout.implicitWidth
    implicitHeight: 30

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: 5

        MaterialIcon {
            id: batteryIcon

            size: Appearance.font.pixelSize.larger
            color: Appearance.md3.on_surface
            icon: Services.BatteryService.materialIcon
            // Alineación vertical mediante propiedad adjunta del layout
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: Services.BatteryService.percentage + "%"
            color: Appearance.md3.on_surface
            // Ancho preferido para que el layout sea estable al cambiar el texto
            Layout.preferredWidth: 35 
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
        }
    }
}