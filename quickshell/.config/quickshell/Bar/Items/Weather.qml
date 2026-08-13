
import qs.Bar.Content
import qs.Bar
import qs.Core.Services
import qs.Panels.Weather
import QtQuick
import Quickshell
Item {
    id: root
    implicitWidth: content.implicitWidth + 18
    implicitHeight: 30
    LazyLoader {
        id: weatherCharge
        loading: interaction.hoveredChanged
        WeatherPopup {
            id: popupWindow
            anchorItem: root
        }
    }
   
    BarBackground {
        id: background
        anchors.fill: parent
        active: interaction.containsMouse
    }

    WeatherContent {
        id: content
        anchors.centerIn: parent
    }

   MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: true
        hoverEnabled: true
        onClicked: {
            const w = weatherCharge.item;
            if (w)
                w.visible = !w.visible;
        } //Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])
        cursorShape: Qt.PointingHandCursor
    }
    
}