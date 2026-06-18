import Quickshell
import QtQuick
import qs.Core.Services as Services
import qs.Components
import qs.Core
import qs.Features.Subwindows
import qs.Bar.Items
BarItem {
    id: root

    readonly property var service: Services.UpdatesTracking

        visible: service.updateCount > 0 || service.checking
        clickable: !service.updating && !service.checking
        onClicked: {
            const w = popupLoader.item
            if (w) w.visible = !w.visible
        }
        radius: 20
        LazyLoader {
            id: popupLoader
            loading: true
            UpdateList {
                id: popup
                anchor.item: root
                anchor.margins.top: 20
                anchor.margins.bottom: 20
                anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
                anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                icon: service.updating ? "downloading" :
                service.checking ? "sync" :
                service.failed ? "warning" :
                "system_update_alt"

                color: service.failed ? Colors.md3.error :
                service.updating ? Colors.md3.primary :
                Colors.md3.on_surface

                // Rotación animada mientras sincroniza
                RotationAnimation on rotation {
                running: service.checking || service.updating
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite

                onRunningChanged: {
                    if (!running)
                    {
                        icon.rotation = 0
                    }
                }

            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !service.checking && !service.updating
            text: service.updateCount
            color: service.failed ? Colors.md3.error : Colors.md3.on_surface
            font.pixelSize: 16
            font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
        }
    }
}