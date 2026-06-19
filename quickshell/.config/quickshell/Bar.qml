import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Bar
import qs.Core.Services as Services

PanelWindow {
    id: root
    
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusiveZone: 38
    WlrLayershell.namespace: "bar"

    
    anchors {
        top: Services.ConfigService.getConfig("bar.position") == "top" || Services.ConfigService.getConfig("bar.position") == "" ? true : false
        right: true
        left: true
        bottom: Services.ConfigService.getConfig("bar.position") == "bottom" ? true : false
    }
    
    margins {
        top: Services.ConfigService.getConfig("bar.position") == "bottom" ? 0 : 3
        bottom: Services.ConfigService.getConfig("bar.position") == "bottom" ? 3 : 0
        right: 3
        left: 3
    }
    
    implicitHeight: 40
    color: "transparent"
    
    MainBar { anchors.fill: parent }
   
}
