import Quickshell
import QtQuick
import qs.Bar.Content
import qs.Panels.Battery

BarItem {
    id: root
    clickable: true
    horizontalPadding: 9

    LazyLoader {
        id: loader
        loading: root.area.hoveredChanged
        component: BatteryPopupWindow {
            id: popupWindow
        }
    }

    onClicked: {
        const w = loader.item;
        if (w)
            w.visible = !w.visible;
    } //Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])

    BatteryContent {
        id: content
        anchors.centerIn: parent
    }
}
