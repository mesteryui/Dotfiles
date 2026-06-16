pragma Singleton
import Quickshell
import Quickshell.Wayland
Singleton {
    id: root

    property bool inhibited: false

    function toggle(): void {
        root.inhibited = !root.inhibited
    }
}
