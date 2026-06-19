pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root 
    property string activeSubmap: ""

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name === "submap") {
                root.activeSubmap = event.data.trim();
            }
        }
    }
}