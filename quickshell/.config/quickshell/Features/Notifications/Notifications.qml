import QtQuick
import Quickshell
import qs.Core.Services

Scope {
    id: root

    // NotificationCenter es PanelWindow pesado pero pasa oculto casi siempre:
    // se difiere. Los popups por pantalla se quedan directos (instantáneos).
    Loader {
        active: NotificationService.centerOpen
        asynchronous: true
        sourceComponent: centerComp
    }

    Component {
        id: centerComp

        NotificationCenter {
            visible: NotificationService.centerOpen
            historyModel: NotificationService.history
        }
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
