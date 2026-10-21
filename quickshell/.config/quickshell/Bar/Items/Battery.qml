import qs.Bar.Content
import qs.Panels.Battery
import QtQuick

BarItem {
    id: root

    clickable: true
    horizontalPadding: 9

    onClicked: popupLoader.toggle()

    BarPopup {
        id: popupLoader

        anchorItem: root
        hovered: root.hovered
        pressed: root.pressed
        component: BatteryPopupWindow {
            id: popupWindow
        }
    }

    BatteryContent {
        id: content

        anchors.centerIn: parent
    }
}
