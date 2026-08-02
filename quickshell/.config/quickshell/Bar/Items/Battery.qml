import Quickshell
import QtQuick
import qs.Bar.Content
import qs.Bar
import qs.Panels.Battery
import qs.Core.Services as Services

Item {
    id: root
    implicitWidth: content.implicitWidth + 18
    implicitHeight: 30
    LazyLoader {
        id: loader
        loading: interaction.hoveredChanged
        BatteryPopupWindow {
            id: popupWindow
            anchor.item: root
            anchor.margins.top: 20
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
            anchor.margins.bottom: 20
            anchor.edges: Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom
            anchor.gravity: anchor.edges
        }
    }
    MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: true
        hoverEnabled: true
        onClicked: {
            const w = loader.item;
            if (w)
                w.visible = !w.visible;
        } //Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "omabat"])
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
