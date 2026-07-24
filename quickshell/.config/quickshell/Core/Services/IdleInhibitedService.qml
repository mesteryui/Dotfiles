pragma Singleton
import Quickshell
import Quickshell.Wayland
import qs.Core.Modules
import Quickshell.Io
Singleton {
    id: root

    readonly property bool inhibited: Persistent.persistence.idle.inhibit

    function toggle(): void {
        Persistent.persistence.idle.inhibit = !root.inhibited
    }
    IpcHandler {
        target: "inhibit"
        function on() {
            Persistent.persistence.idle.inhibit = true
        }
        function off() {
            Persistent.persistence.idle.inhibit = false
        }
        function toggle() {
            root.toggle()
        }
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
