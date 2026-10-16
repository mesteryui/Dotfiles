pragma Singleton

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

        onNotification: n => NotificationData.pushHistory(n)
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
