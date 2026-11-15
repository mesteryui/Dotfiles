pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// NotificationService: la FUENTE de notificaciones (servidor + UI abierta).
// El DATO vive en NotificationData: historial, dnd, formato. Este singleton
// solo empuja (onNotification -> pushHistory) y guarda centerOpen + IPC.
Singleton {
    id: root

    property bool centerOpen: false

    readonly property alias server: notificationServer

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodySupported: true
        imageSupported: true
        actionIconsSupported: true

        onNotification: n => {
            // tracked = true es lo que mantiene viva la notificación y la
            // expone en trackedNotifications (el toast). No la guardamos en
            // el historial: al expirar/cerrar se libera también su imagen.
            n.tracked = true;
            NotificationData.pushHistory(n);
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }

        function show(): void {
            root.centerOpen = true;
        }

        function hide(): void {
            root.centerOpen = false;
        }

        function dndToggle() {
            NotificationData.toggleDnd();
        }
    }
}
