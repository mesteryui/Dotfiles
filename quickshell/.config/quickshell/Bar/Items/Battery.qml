import Quickshell
import QtQuick
import qs.Bar.Content
import qs.Bar
Item {
    id: root
    implicitWidth: content.implicitWidth + 18
    implicitHeight: 30

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
