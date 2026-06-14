import Quickshell
import QtQuick
import Quickshell.Wayland
import QtQuick.Effects

PanelWindow {
    id: root
    visible: false
    WlrLayershell.namespace: "osd_window"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore
    color: "transparent"
    default property alias content: container.data
    anchors {
        bottom: false
        top: true
    }
    margins.bottom: 50
    margins.top: 50
    Timer {
        id: osdTimer
        repeat: false
        interval: 3000
        running: root.visible
        onTriggered: {
            root.visible = false;
        }
    }
    Item {
        id: container
        anchors.fill: parent
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }
}
