import QtQuick
import Quickshell
import qs.Core.Services

Scope {
    id: root

    NotificationCenter {
        visible: NotificationService.centerOpen
        historyModel: NotificationService.history
    }
    Variants {
        model: Quickshell.screens
        delegate: NotificationPopups {
            required property ShellScreen modelData
            screen: modelData
            trackedNotifications: NotificationService.server.trackedNotifications
        }
    }
}
