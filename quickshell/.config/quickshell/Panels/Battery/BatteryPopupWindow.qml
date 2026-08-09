import Quickshell
import qs.Core
import qs.Shared.Background

PopupWindow {
    id: root
    color: "transparent"
    visible: false
    grabFocus: true
    implicitWidth: popupContent.implicitWidth + 24
    implicitHeight: popupContent.implicitHeight + 24
    
    SurfaceBackground {
        id: surface
        anchors.fill: parent
        color: Appearance.md3.surface
        
    }
    BatteryPopupContent {
        id: popupContent
        anchors.centerIn: parent
    }
}