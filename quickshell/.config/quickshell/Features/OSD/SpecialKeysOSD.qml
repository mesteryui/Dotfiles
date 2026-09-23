import qs.Core
import qs.Core.Services
import qs.Primitives
import qs.Shared.Background
import QtQuick
import M3Shapes

BaseOSD {
    id: keyOSD

    implicitWidth: contentRow.implicitWidth + 32
    implicitHeight: contentRow.implicitHeight + 16
    type: "specialKeys"

    property string osdIcon: "keyboard"
    property string osdText: ""
    property color activeColor: Appearance.md3.on_surface
    // Forma-identidad por tecla: Diamond(CapsLock) · Cookie4Sided(NumLock) · Circle(desactivado).
    property int keyShape: MaterialShape.Circle

    Connections {
        target: KeyboardThings

        function onCapsLockOnChanged() {
            const capsActive = KeyboardThings.capsLockOn;
            keyOSD.osdText = I18nService.getTranslation("osd.caps_lock.label", "Bloq Mayús %1").arg(capsActive ? I18nService.getTranslation("osd.caps_lock.activated", "Activado") : I18nService.getTranslation("osd.caps_lock.deactivated", "Desactivado"));
            keyOSD.keyShape = capsActive ? MaterialShape.Diamond : MaterialShape.Circle;
            keyOSD.show();
        }

        function onNumsLockChanged() {
            const numLockActive = KeyboardThings.numsLock;
            keyOSD.osdText = "Bloq Num " + (numLockActive ? "activado" : "desactivado");
            keyOSD.keyShape = numLockActive ? MaterialShape.Cookie4Sided : MaterialShape.Circle;
            keyOSD.show();
        }
    }

    PopupBackground {
        anchors.fill: parent
        color: Appearance.md3.surface
        radius: Appearance.shape.normal
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 10

        // Icono directo, sin contenedor (keyShape se conserva por
        // compatibilidad: solo decide el pulso cuando hay tecla activa).
        Item {
            implicitWidth: 34
            implicitHeight: 34
            anchors.verticalCenter: parent.verticalCenter

            MaterialIcon {
                anchors.centerIn: parent
                icon: keyOSD.osdIcon
                size: 28
                color: keyOSD.keyShape !== MaterialShape.Circle ? Appearance.md3.primary : Appearance.md3.on_surface

                // Pulso sutil cuando una tecla está activa.
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: keyOSD.keyShape !== MaterialShape.Circle

                    NumberAnimation { from: 1; to: 1.1; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.1; to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }
        }

        StyledText {
            font.family: ConfigService.configs.appearance.fontSans
            font.pixelSize: Appearance.font.pixelSize.title
            font.bold: true
            color: Appearance.md3.on_surface
            text: keyOSD.osdText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
