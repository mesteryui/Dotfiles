pragma Singleton
import Quickshell
import Quickshell.Wayland
import qs.Core.Modules
Singleton {
    id: root

    readonly property bool inhibited: Persistent.persistence.idle.inhibit

    function toggle(): void {
        Persistent.persistence.idle.inhibit = !root.inhibited
    }
    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            implicitHeight: 0
            implicitWidth: 0
            color: "transparent"
            anchors {
                right: true
                bottom: true
            }
            mask: Region {
                item: null
            }
        }
        
        enabled: root.inhibited
    }
}
