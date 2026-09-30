import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import qs.Shared.Background
import QtQuick
import QtQuick.Layouts
import M3Shapes

// OSD de porcentaje con icono expresivo (m3shapes).
// Lenguaje de formas: reposo = Circle, activo = cookies/Puffy,
// silencio (mute) = ClamShell, brillo = morph continuo Sunny→VerySunny.
BaseOSD {
    id: root

    required property real percentage
    required property string icon
    property alias iconItem: iconItem

    // Silencio (p. ej. muteado): ClamShell (boca cerrada) + colores error.
    property bool alert: false
    // Morph discreto por nivel (volumen/micro): más diferenciación visual.
    property int shapeLow: MaterialShape.Circle
    property int shapeMid: MaterialShape.Diamond
    property int shapeHigh: MaterialShape.Cookie9Sided
    // Morph continuo atado al valor (brillo = luz, volumen = energia).
    property bool continuousMorph: false
    property int morphFrom: MaterialShape.Sunny
    property int morphTo: MaterialShape.VerySunny
    // Para volumen/micro continuo: Circle → Cookie9Sided (energía sonora).
    property int soundMorphFrom: MaterialShape.Circle
    property int soundMorphTo: MaterialShape.Cookie9Sided

    // Nivel recortado a [0,1] para el morph manual (el volumen puede pasar de 1.0).
    property real clampedLevel: Math.min(1, Math.max(0, root.percentage))
    property int discreteShape: root.alert ? MaterialShape.ClamShell : root.percentage < 0.34 ? root.shapeLow : root.percentage < 0.67 ? root.shapeMid : root.shapeHigh
    // Cuando alert y continuousMorph, forzamos ClamShell sin interpolar.
    property int effectiveMorphFrom: root.alert ? MaterialShape.ClamShell : (root.continuousMorph ? (root.type === "brightness" ? root.morphFrom : root.soundMorphFrom) : root.discreteShape)
    property int effectiveMorphTo: root.alert ? MaterialShape.ClamShell : (root.continuousMorph ? (root.type === "brightness" ? root.morphTo : root.soundMorphTo) : root.discreteShape)

    implicitWidth: 340
    implicitHeight: 58

    PopupBackground {
        anchors.fill: parent
        color: Appearance.md3.surface
        radius: Appearance.shape.large
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.m
        width: parent.width - 40

        // Icono directo, sin contenedor (las props de forma se conservan
        // por compatibilidad pero ya no se pintan).
        Item {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignVCenter

            MaterialIcon {
                id: iconItem

                anchors.centerIn: parent
                icon: root.icon
                size: Appearance.font.pixelSize.huge
                color: root.alert ? Appearance.md3.error : Appearance.md3.on_surface

                // Pulso en alerta (antes respiraba la forma).
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.alert

                    NumberAnimation { from: 1; to: 1.1; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.1; to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }

        StyledProgressBar {
            id: barItem

            from: 0.0
            to: 1.0
            value: root.percentage
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            id: textPercentage

            text: Math.round(root.percentage * 100) + "%"
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.md3.on_surface
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
