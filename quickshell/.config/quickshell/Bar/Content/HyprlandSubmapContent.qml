import QtQuick
import QtQuick.Layouts
import qs.Primitives
import qs.Core
Item {
    id: root
    property string text: ""
    
    // El root simplemente hereda el tamaño que el layout determine como ideal
    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    RowLayout {
        id: layout
        // Llenamos el contenedor padre para que las alineaciones funcionen
        anchors.fill: parent 
        spacing: 2 // Espaciado estándar de M3 [2]

        MaterialIcon {
            icon: "layers"
            size: Appearance.font.pixelSize.normal
            color: Appearance.md3.on_primary_container
            // Reservamos el espacio exacto para el icono
            Layout.preferredWidth: 20 
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: root.text
            color: Appearance.md3.on_primary_container
            font.pixelSize: Appearance.font.pixelSize.normal
            // Hacemos que el texto tome el espacio sobrante
            Layout.fillWidth: true 
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight // Evita que el texto rompa el layout si es muy largo
        }
    }
}