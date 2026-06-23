import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Hyprland
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import qs.Shared.Background

BaseOSD {
    id: keyOSD

    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20

    property string osdIcon: "keyboard"
    property string osdText: ""
    property color activeColor: Colors.md3.on_surface

    property bool capsActive: false
    property bool numActive: false

    PopupBackground {
        anchors.fill: parent
        color: Colors.md3.surface
        radius: 30
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 12

        MaterialIcon {
            icon: keyOSD.osdIcon
            size: 30
            color: Colors.md3.on_surface
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            font.family: Services.ConfigService.configs.appearence.fontSans
            font.pixelSize: 22
            font.bold: true
            color: Colors.md3.on_surface
            text: keyOSD.osdText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
