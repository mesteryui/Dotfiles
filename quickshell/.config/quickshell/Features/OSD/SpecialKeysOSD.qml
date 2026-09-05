import qs.Core
import qs.Core.Services
import qs.Primitives
import qs.Shared.Background
import QtQuick

BaseOSD {
    id: keyOSD

    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20
    type: "specialKeys"

    property string osdIcon: "keyboard"

    property string osdText: ""

    property color activeColor: Appearance.md3.on_surface

    Connections {
        target: KeyboardThings

        function onCapsLockOnChanged() {
            const capsActive = KeyboardThings.capsLockOn;
            keyOSD.osdText = I18nService.getTranslation("osd.capsLock.text").arg(capsActive ? I18nService.getTranslation("osd.capsLock.activate") : I18nService.getTranslation("osd.capsLock.deactivate"));
            keyOSD.show();
        }

        function onNumsLockChanged() {
            const numLockActive = KeyboardThings.numsLock;
            keyOSD.osdText = "Nums Lock " + (numLockActive ? "activado" : "desactivado");
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
        spacing: 12

        MaterialIcon {
            icon: keyOSD.osdIcon
            size: 30
            color: Appearance.md3.on_surface
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            font.family: ConfigService.configs.appearence.fontSans
            font.pixelSize: Appearance.font.pixelSize.title
            font.bold: true
            color: Appearance.md3.on_surface
            text: keyOSD.osdText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
