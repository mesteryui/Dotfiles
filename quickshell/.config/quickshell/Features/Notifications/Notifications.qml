import QtQuick
import Quickshell

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
