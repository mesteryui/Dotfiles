import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
PanelWindow {
    id: window
    visible: false
    WlrLayershell.namespace: "osd_window"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore
    color: "transparent"
    Timer {
        id: osdTimer
        repeat: false
        interval: 3000
        running: window.visible
        onTriggered: {
            window.visible = false;
        }
    }
    function show(): void
    {
        window.visible = true
    }
    default property alias content: container.data
    anchors {
        bottom: false
        top: true
    }
    margins.bottom: 50
    margins.top: 50
    Item {
        id: container
        anchors.fill: parent
        opacity: window.visible ? 1.0 : 0.0
        Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }
}
}