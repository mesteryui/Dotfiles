import Quickshell
import QtQuick
import qs.Core
import qs.Core.Services as Services
import qs.Features.Windows
import qs.Components

BarItem {
    id: root
    LazyLoader {
        id: popupLoader
        loading: true
        PanelWithControls {
            id: popup
            anchor.item: root
            anchor.margins.top: 13
            anchor.margins.bottom: 13
            anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
            anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        }
    }
    clickable: true
    onClicked: {
        const w = popupLoader.item
        if (w) w.visible = !w.visible
    }
    MaterialIcon {
        icon: "rocket_launch"
        size: 20
        color: Colors.md3.on_surface
        anchors.centerIn: parent
    }
}
