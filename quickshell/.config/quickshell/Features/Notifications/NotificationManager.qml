pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.Core.Modules
import Quickshell.Io

Singleton {
    id: root
    property bool centerOpen: false
    readonly property bool dnd: Persistent.persistence.notifications.dnd

    readonly property alias history: historyModel
    readonly property alias server: notificationServer

    function toggleDnd() {
        Persistent.persistence.notifications.dnd = !Persistent.persistence.notifications.dnd;
    }

    onDndChanged: {
        if (dnd && notificationServer.trackedNotifications) {
            const list = notificationServer.trackedNotifications;
            const count = list.count !== undefined ? list.count : list.length;
            for (let i = count - 1; i >= 0; i--) {
                let n = list.get ? list.get(i) : list[i];
                if (n && n.urgency !== NotificationUrgency.Critical) {
                    n.dismiss();
                }
            }
        }
    }

    ListModel {
        id: historyModel
    }

    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: n => {
            historyModel.insert(0, {
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                urgency: n.urgency,
                time: Qt.formatDateTime(new Date(), "HH:mm")
            });
            if (n.urgency !== NotificationUrgency.Critical && root.dnd) {
                return;
            }
            n.tracked = true;
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
            root.toggleDnd();
        }
    }
}
