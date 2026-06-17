import Quickshell
import QtQuick
import "../../Core"
import "../../Core/Services" as Services
import "../../Features/Windows"
import "../../Components"

BarItem {
    id: root
    PanelWithControls {
        id: popup
        anchor.item: root
        anchor.margins.top: 13
        anchor.margins.bottom: 13
        anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
        anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
    }
    clickable: true
    onClicked: popup.visible = !popup.visible
    MaterialIcon {
        icon: "rocket_launch"
        size: 20
        color: Colors.md3.on_surface
        anchors.centerIn: parent
    }
}
