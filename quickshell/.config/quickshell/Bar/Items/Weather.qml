
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
            anchor.item: root
            anchor.margins {
                top: 20
                bottom: 20
            }
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
            anchor.edges: ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom
            anchor.gravity: ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom
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