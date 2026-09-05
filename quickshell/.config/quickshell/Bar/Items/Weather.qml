pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Panels.Weather
import QtQuick
import Quickshell

BarItem {
    id: root

    clickable: true
    horizontalPadding: 9

    LazyLoader {
        id: weatherCharge

        loading: root.area.hoveredChanged

        WeatherPopup {
            id: popupWindow

            anchorItem: root
        }
    }

    WeatherContent {
        id: content

        anchors.centerIn: parent
    }

    onClicked: {
        const w = weatherCharge.item;
        if (w)
            w.visible = !w.visible;
    } //Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])
}
