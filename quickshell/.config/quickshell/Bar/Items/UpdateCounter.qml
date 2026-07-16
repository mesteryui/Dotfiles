pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.Core.Services as Services
import qs.Bar.Content
import qs.Panels.Updates
import qs.Bar

Item {
    id: root

    implicitWidth: content.implicitWidth + 24 // Padding horizontal
    implicitHeight: 30
    scale: interaction.containsMouse ? 1.08 : 1

    readonly property var service: Services.UpdatesTracking

    visible: service.updateCount > 0 || service.checking

    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const w = popupLoader.item
            if (w) w.visible = !w.visible
        }
        enabled: !root.service.updating && !root.service.checking
    }

    BarBackground {
        anchors.fill: parent
        active: interaction.containsMouse
    }

    LazyLoader {
        id: popupLoader
        loading: true
        component: UpdateList {
            id: popup
            anchor.item: root
            anchor.margins.top: 20
            anchor.margins.bottom: 20
            anchor.edges: (Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
            anchor.gravity: (Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
        }
    }

    UpdateCounterContent {
        id: content
        anchors.centerIn: parent
        service: root.service
    }
}