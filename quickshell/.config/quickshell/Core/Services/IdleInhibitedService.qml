pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property alias inhibited: props.inhibited

    function toggle(): void {
        props.inhibited = !props.inhibited;
    }

    PersistentProperties {
        id: props

        property bool inhibited

        reloadableId: "idleInhibitor"
    }

    IpcHandler {
        target: "inhibit"

        function on() {
            props.inhibited = true;
        }

        function off() {
            props.inhibited = false;
        }

        function toggle() {
            root.toggle();
        }
    }
    IdleInhibitor {
        id: inhibitor

        window: PanelWindow {
            implicitHeight: 0
            implicitWidth: 0
            color: "transparent"
            // Solo se mapea mientras inhibe: apagado no debe dejar una
            // superficie 1x1 viva con su contexto GL.
            mask: Region {
                item: null
            }
        }

        enabled: props.inhibited
    }
}
