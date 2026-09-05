import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    WlrLayershell.exclusionMode: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:wallhaven"

    WallhavenWindowContent {
        
    }
}