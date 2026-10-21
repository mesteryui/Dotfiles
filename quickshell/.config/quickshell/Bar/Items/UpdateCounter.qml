pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import qs.Bar.Content
import qs.Panels.Updates
import QtQuick

BarItem {
    id: root

    clickable: !root.service.updating && !root.service.checking
    horizontalPadding: 12
    scale: hovered ? 1.08 : 1

    readonly property var service: Services.UpdatesTracking
    visible: service.updateCount > 0 || service.checking

    onClicked: popupLoader.toggle()

    BarPopup {
        id: popupLoader

        anchorItem: root
        hovered: root.hovered
        pressed: root.pressed
        component: UpdateList {
            id: popup
        }
    }

    UpdateCounterContent {
        id: content

        anchors.centerIn: parent
        service: root.service
    }
}
