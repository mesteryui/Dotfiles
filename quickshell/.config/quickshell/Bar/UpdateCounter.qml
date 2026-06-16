import Quickshell
import QtQuick
import "../Core/Services" as Services
import "../Components"
import "../Core"
import "../Features/Subwindows"
import "Items"
BarItem {
    id: root

    readonly property var service: Services.UpdatesTracking

    visible:   service.updateCount > 0 || service.checking
    clickable: !service.updating && !service.checking
    onClicked: popup.visible = !popup.visible
    radius: 20

    UpdateList {
        id: popup
        anchor.item: root
        anchor.margins.top: 30
        anchor.margins.bottom: 30
        anchor.edges: Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom
        anchor.gravity: Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            size: 20
            icon: service.updating  ? "downloading"       :
                  service.checking  ? "sync"               :
                  service.failed    ? "warning"            :
                                      "system_update_alt"

            color: service.failed   ? Colors.error         :
                   service.updating ? Colors.primary        :
                                      Colors.on_surface

            // Rotación animada mientras sincroniza
            RotationAnimation on rotation {
                running:  service.checking || service.updating
                from:     0
                to:       360
                duration: 1000
                loops:    Animation.Infinite
                
                onRunningChanged: {
                    if (!running) {
                        icon.rotation = 0
                    }
                }

            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible:   !service.checking && !service.updating
            text:      service.updateCount
            color:     service.failed ? Colors.error : Colors.on_surface
            font.pixelSize: 16
            font.family:    Services.ConfigService.getConfig("fontSans", "sans-serif")
        }
    }
}