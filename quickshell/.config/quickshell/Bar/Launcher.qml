import Quickshell
import QtQuick
import ".."
import "../Services" as Services
import "../InterfaceThings"
BarItem {
    id: root
    PanelWithControls {
        id: popup
        anchor.item: root          // ← ancla al texto
        anchor.margins.top: 30
        anchor.edges: Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom
        anchor.gravity: Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom
    }
    clickable: true
    onClicked: popup.visible = !popup.visible
    Text {
        text: ""
        anchors.centerIn: parent
        color: Colors.on_surface
    }
}
