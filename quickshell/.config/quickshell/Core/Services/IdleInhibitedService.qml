pragma Singleton
import Quickshell
import Quickshell.Wayland
Singleton {
    id: root

    property alias inhibited: persistent.activated
    PersistentProperties {
        id: persistent
        property bool activated: false
    }
    function toggle(): void {
        root.inhibited = !root.inhibited
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
