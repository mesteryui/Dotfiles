pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Panels.Weather
import QtQuick

BarItem {
    id: root

    clickable: true
    horizontalPadding: 9

    BarPopup {
        id: weatherCharge

        anchorItem: root
        hovered: root.hovered
        pressed: root.pressed
        component: WeatherPopup {
            id: popupWindow
        }
    }

    WeatherContent {
        id: content

        anchors.centerIn: parent
    }

    onClicked: weatherCharge.toggle()
}
