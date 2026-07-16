import qs.Shared.Background
import qs.Primitives
import QtQuick.Layouts
import qs.Core.Services
import QtQuick

BaseOSD {
    id: root
    property string osdText: ""
    property string osdIcon: ""

    PopupBackground {
        id: popup
        anchors.fill: parent
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16 // MEJORA: Evita que el contenido se pegue a los bordes del popup
        spacing: 12
        
        MaterialIcon {
            icon: root.osdIcon
            Layout.alignment: Qt.AlignVCenter // Centra el icono verticalmente
        }
        
        StyledText {
            text: root.osdText
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true 
            elide: Text.ElideRight // MEJORA: Si el título de la canción es muy largo, pone "..." en vez de desbordar el OSD
        }
    }
}