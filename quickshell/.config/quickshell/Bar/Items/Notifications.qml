pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Core
import qs.Core.Services as Services
import qs.Panels.Notifications
import qs.Primitives
import QtQuick

BarItem {
    id: root

    clickable: true
    backgroundColor: root.popupOpen ? Appearance.md3.primary_container : Appearance.md3.surface_container_high

    readonly property bool popupOpen: popupLoader.opened

    // Click izq abre el popup, click dcho alterna DND, central limpia
    area.acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            Services.NotificationData.toggleDnd();
        } else if (mouse.button === Qt.MiddleButton) {
            Services.NotificationData.clearHistory();
        } else {
            popupLoader.toggle();
        }
    }

    NotificationsContent {
        anchors.centerIn: parent
    }

    BarPopup {
        id: popupLoader

        anchorItem: root
        hovered: root.hovered
        pressed: root.pressed
        component: NotificationPopupWindow {
            id: popupWindow
        }
    }

    BarToolTip {
        anchorItem: root

        text: {
            const n = Services.NotificationData.history ? Services.NotificationData.history.count : 0;
            if (Services.NotificationData.dnd)
                return "No molestar activado · " + n + " en historial (click dcho para desactivar)";
            if (n > 0)
                return n + " notificaciones (click dcho: no molestar, central: limpiar)";
            return "Sin notificaciones (click dcho: no molestar)";
        }
        shown: root.hovered && !root.popupOpen
    }
}
