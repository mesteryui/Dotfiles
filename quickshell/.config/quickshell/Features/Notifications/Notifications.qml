import Quickshell
import QtQuick

Scope {
    id: root

    NotificationCenter {
        visible: NotificationManager.centerOpen
        historyModel: NotificationManager.history
    }

    NotificationPopups {
        trackedNotifications: NotificationManager.server.trackedNotifications
    }
}
