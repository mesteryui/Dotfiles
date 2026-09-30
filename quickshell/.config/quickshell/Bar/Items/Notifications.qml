pragma ComponentBehavior: Bound

import qs.Bar.Content
import qs.Core
import qs.Core.Services as Services
import qs.Panels.Notifications
import qs.Primitives
import QtQuick
import QtQuick.Controls
import Quickshell

BarItem {
    id: root

    clickable: true
    backgroundColor: root.popupOpen ? Appearance.md3.primary_container : Appearance.md3.surface_container_high

    property bool popupOpen: false

    // Click izq abre el popup, click dcho alterna DND, central limpia
    area.acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            Services.NotificationService.toggleDnd();
        } else if (mouse.button === Qt.MiddleButton) {
            if (Services.NotificationService.history)
                Services.NotificationService.history.clear();
        } else {
            const w = popupLoader.item;
            if (w)
                w.visible = !w.visible;
        }
    }

    NotificationsContent {
        anchors.centerIn: parent
    }

    LazyLoader {
        id: popupLoader

        loading: root.area.hoveredChanged || root.area.pressed
        component: NotificationPopupWindow {
            anchorItem: root
        }
    }

    // El popup se cierra solo al perder el foco (HyprlandFocusGrab):
    // sincroniza el resaltado del item.
    Connections {
        target: popupLoader.item
        ignoreUnknownSignals: true

        function onVisibleChanged() {
            root.popupOpen = popupLoader.item.visible;
        }
    }

    ToolTip {
        id: tooltip

        // Debajo del icono, centrado; si la barra está abajo, encima.
        property bool barAtBottom: Services.ConfigService.configs.bar.position === "bottom"
        x: (parent.width - width) / 2
        y: barAtBottom ? -height - 8 : parent.height + 8
        text: {
            const n = Services.NotificationService.history ? Services.NotificationService.history.count : 0;
            if (Services.NotificationService.dnd)
                return "No molestar activado · " + n + " en historial (click dcho para desactivar)";
            if (n > 0)
                return n + " notificaciones (click dcho: no molestar, central: limpiar)";
            return "Sin notificaciones (click dcho: no molestar)";
        }
        visible: root.area.containsMouse && !root.popupOpen
        delay: 500
        timeout: 5000

        contentItem: StyledText {
            text: tooltip.text
            color: Appearance.md3.inverse_on_surface
            font.pixelSize: 12
            wrapMode: Text.NoWrap
        }

        background: Rectangle {
            color: Appearance.md3.inverse_surface
            radius: Appearance.shape.extraSmall
        }

        padding: 8
        horizontalPadding: 12
    }
}
