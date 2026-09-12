import QtQuick
import Quickshell
import qs.Core.Services

Scope {
    id: root

    NotificationCenter {
        visible: NotificationService.centerOpen
        historyModel: NotificationService.history
    }

    NotificationPopups {
        trackedNotifications: NotificationService.server.trackedNotifications
    }
}
