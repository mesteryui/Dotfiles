pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.Core.Modules
import Quickshell.Io

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
