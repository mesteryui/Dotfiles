import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import qs.Core
import qs.Bar.Content
import qs.Bar
Item {
    id: root
    implicitWidth: content.implicitWidth + 18
    implicitHeight: 30
    scale: interaction.pressed ? 0.92: (interaction.containsMouse ? 1.05 : 1.0)

    MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: true
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])
        cursorShape: Qt.PointingHandCursor
    }
    BarBackground {
        id: background
        anchors.fill: parent
        active: interaction.containsMouse
    }
    BatteryContent {
        id: content
        anchors.centerIn: parent
        
    }
}
