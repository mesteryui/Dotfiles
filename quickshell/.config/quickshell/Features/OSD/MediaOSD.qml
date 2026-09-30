import qs.Shared.Background
import qs.Primitives
import qs.Core
import qs.Core.Services
import QtQuick
import QtQuick.Layouts
import M3Shapes

BaseOSD {
    id: root

    property string osdText: ""
    property string osdIcon: ""
    // Reproduciendo: Puffy (vivo). Pausado: Circle (estable).
    property bool playing: false

    PopupBackground {
        id: popup

        anchors.fill: parent
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.l
        spacing: Appearance.spacing.m

        // Contenedor expresivo con forma por estado.
        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignVCenter

            MaterialShape {
                anchors.fill: parent
                shape: root.playing ? MaterialShape.Puffy : MaterialShape.Circle
                animationDuration: 300
                color: Appearance.md3.primary_container

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.osdIcon
                    size: Appearance.font.pixelSize.larger
                    color: Appearance.md3.on_primary_container
                }
            }
        }

        StyledText {
            text: root.osdText
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
