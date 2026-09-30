import QtQuick
import Quickshell
import qs.Core.Services

Scope {
    id: root

    // NotificationCenter es PanelWindow pesado pero pasa oculto casi siempre:
    // LazyLoader lo incuba en background y lo cachea (su visible ya va
    // atado a centerOpen). Los popups por pantalla se quedan directos.
    LazyLoader {
        id: centerLoader
        loading: NotificationService.centerOpen
        component: centerComp
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
