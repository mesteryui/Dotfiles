import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Core"
import "../../Components"
import "."
import Quickshell.Wayland

BaseOSD {
    id: root

    required property real percentage
    required property string icon
    implicitWidth: 320
    implicitHeight: 60

    
    function show() {
        root.visible = true;
    }
    Rectangle {
        anchors.fill: parent
        color: Colors.surface
        radius: height / 2

        Row {
            anchors.centerIn: parent
            spacing: 15
            width: parent.width - 40

            MaterialIcon {
                icon: root.icon
                anchors.verticalCenter: parent.verticalCenter
                size: 24
                color: Colors.on_surface
                width: 30
            }

            Rectangle {
                id: barBackground
                height: 10
                width: 180
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.surface_variant
                radius: 5
                

                Rectangle {
                    id: barForeground
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: parent.width * Math.min(Math.max(root.percentage, 0), 1)
                    color: Colors.primary
                    radius: parent.radius
                    Behavior on width {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }

            Text {
                text: Math.round(root.percentage * 100) + "%"
                font.pixelSize: 16
                color: Colors.on_surface
                width: 40
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
