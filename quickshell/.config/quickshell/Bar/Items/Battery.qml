import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import qs.Core
import qs.Bar.Content
import qs.Bar
Item {
    id: root
    implicitWidth: content.implicitWidth + 10
    implicitHeight: 30

    MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: true
        onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])
        cursorShape: Qt.PointingHandCursor
    }
    BarBackground {
        id: background
        anchors.fill: parent
        scale: interaction.pressed ? 0.92 : (interaction.enabled && interaction.containsMouse ? 1.05 : 1.0)
        Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutQuad
        }
        }
    }
    BatteryContent {
        id: content
        anchors.centerIn: parent
        
    }
}
