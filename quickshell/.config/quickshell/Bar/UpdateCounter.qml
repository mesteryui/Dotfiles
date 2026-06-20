import Quickshell
import QtQuick
import qs.Core.Services as Services
import qs.Core
import qs.Bar.Content
import qs.Features.Subwindows
import qs.Bar.Items
Item {
    id: root

    implicitWidth: content.implicitWidth + 24 // Padding horizontal
    implicitHeight: 30

    readonly property var service: Services.UpdatesTracking

    visible: service.updateCount > 0 || service.checking


        MouseArea {
            id: interaction
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const w = popupLoader.item
                if (w) w.visible = !w.visible
            }
            enabled: !root.service.updating && !root.service.checking
        }

        BarBackground {
            anchors.fill: parent
            highlighted: interaction.containsMouse
        }
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
        UpdateCounterContent {
            id: content
            anchors.centerIn: parent
            service: root.service
        }

    }