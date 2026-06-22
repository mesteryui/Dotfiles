import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Bar
import qs.Core
import qs.Core.Services as Services

PanelWindow {
    id: root
    
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusiveZone: 38
    WlrLayershell.namespace: "bar"

    
    anchors {
        top: Services.ConfigService.configs.bar.position == "top" || Services.ConfigService.configs.bar.position == "" ? true : false
        right: true
        left: true
        bottom: Services.ConfigService.configs.bar.position == "bottom" ? true : false
    }
    
    margins {
        top: Services.ConfigService.configs.bar.position == "bottom" ? 0 : 3
        bottom: Services.ConfigService.configs.bar.position == "bottom" ? 3 : 0
        right: 3
        left: 3
    }
    implicitWidth: content.width
    implicitHeight: 40
    color: "transparent"
    
    BarBackground {
        anchors.fill: parent
        color: Qt.alpha(Colors.md3.surface,0.93)
        radius: 30
    }

    MainBar { 
        id: content
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
    }
   
}
