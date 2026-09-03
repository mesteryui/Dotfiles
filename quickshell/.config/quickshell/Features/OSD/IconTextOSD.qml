import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Primitives
import qs.Shared.Background

// Base para OSDs de icono + texto centrado (batería, teclas especiales, etc.).
// Mismo rol que PercentageOSD, pero para OSDs sin barra de progreso.
BaseOSD {
    id: root

    required property string osdIcon
    required property string osdText

    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20

    PopupBackground {
        anchors.fill: parent
        color: Appearance.md3.surface
        radius: Appearance.shape.normal
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 10

        MaterialIcon {
            icon: root.osdIcon
            size: 30
            color: Appearance.md3.on_surface
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: root.osdText
            font.pixelSize: 26
            color: Appearance.md3.on_surface
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
