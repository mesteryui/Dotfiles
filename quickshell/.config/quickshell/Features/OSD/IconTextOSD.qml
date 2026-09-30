import qs.Core
import qs.Primitives
import qs.Shared.Background
import QtQuick
import QtQuick.Layouts
import M3Shapes

// Base para OSDs de icono + texto centrado (batería, teclas especiales, etc.).
// Mismo rol que PercentageOSD, pero para OSDs sin barra de progreso.
// El icono va directo, sin contenedor: el estado se lee en su color y pulso.
// iconShape se conserva (sin efecto visual) para no romper asignaciones.
BaseOSD {
    id: root

    required property string osdIcon
    required property string osdText

    // Forma-identidad del OSD (p. ej. batería = Circle, juego = Cookie6Sided).
    property int iconShape: MaterialShape.Circle
    // Resaltado tonal (p. ej. modo juego activado).
    property bool highlighted: false
    // Alerta (p. ej. batería crítica): Boom con respiración.
    property bool alert: false

    implicitWidth: contentRow.implicitWidth + 32
    implicitHeight: contentRow.implicitHeight + 16

    PopupBackground {
        anchors.fill: parent
        color: Appearance.md3.surface
        radius: Appearance.shape.normal
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: Appearance.spacing.s

        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter

            // Icono sin contenedor: el estado se lee en el color y el pulso.
            MaterialIcon {
                anchors.centerIn: parent
                icon: root.osdIcon
                size: 28
                color: root.alert ? Appearance.md3.error : root.highlighted ? Appearance.md3.primary : Appearance.md3.on_surface

                // Pulso solo en alerta; el resaltado (modo juego) queda
                // estático en primary para no marear.
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.alert

                    NumberAnimation { from: 1; to: 1.1; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.1; to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }
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
