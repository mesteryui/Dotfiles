import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    property int implicitHeight: 20
    property int implicitWidth: 20
    default property alias content: container.data
    Timer {
        id: osdTimer
        repeat: false
        interval: 3000
        running: window.visible
        onTriggered: {
            window.visible = false;
        }
    }
    function show(): void {
        window.visible = true
    }

    PanelWindow {
        id: window
        visible: false
        screen: root.focusedScreen
        WlrLayershell.namespace: "osd_window"
        WlrLayershell.layer: WlrLayer.Overlay
        implicitHeight: root.implicitHeight
        implicitWidth: root.implicitWidth
        exclusionMode: WlrLayershell.Ignore
        exclusiveZone: 0
        color: "transparent"

                Connections {
                    target: root
                    function onFocusedScreenChanged() {
                        window.screen = root.focusedScreen;
                    }
                }

                anchors.top: true
                margins.top: 55
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
    }