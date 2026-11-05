import qs.Core.Services
import QtQuick
import Quickshell

Scope {
    id: root

    // NotificationCenter es PanelWindow pesado pero pasa oculto casi siempre:
    // LazyLoader lo carga al abrir y lo destruye al cerrar (loading sigue a
    // centerOpen). Los popups por pantalla se quedan directos.
    LazyLoader {
        id: centerLoader

        loading: NotificationService.centerOpen
        component: centerComp
    }

        Component {
            id: centerComp

            NotificationCenter {
                visible: NotificationService.centerOpen
                historyModel: NotificationData.history
            }
        }
        Variants {
            model: Quickshell.screens ?? []
            delegate: NotificationPopups {
                required property ShellScreen modelData

                screen: modelData
                trackedNotifications: NotificationService.server.trackedNotifications
            }
        }
    }
