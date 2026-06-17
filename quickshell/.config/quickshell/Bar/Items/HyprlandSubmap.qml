import Quickshell
import QtQuick
import Quickshell.Hyprland
import "../../Core"
import "../../Components"

Rectangle {
    id: root
    visible: inSubmap
    color: Colors.md3.primary_container
    radius: 20
    implicitWidth: submapRow.implicitWidth + 16
    implicitHeight: 30

    property string activeSubmap: ""
    property bool inSubmap: activeSubmap !== ""

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name === "submap") {
                root.activeSubmap = event.data.trim();
            }
        }
    }
    
    Row {
        id: submapRow
        anchors.centerIn: parent
        spacing: 6
        
        MaterialIcon {
            icon: "layers"
            size: 16
            color: Colors.md3.on_primary_container
        }
        
        Text {
            text: root.activeSubmap
            color: Colors.md3.on_primary_container
            font.pixelSize: 13
            font.weight: Font.Medium
            font.family: "sans-serif"
        }
    }
}
