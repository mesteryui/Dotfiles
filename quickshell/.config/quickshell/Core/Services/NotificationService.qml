// Services/NotificationService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property alias dnd: settings.dnd
    property alias notifications: server.trackedNotifications
    readonly property alias history: settings.history

    function clearHistory() {
        settings.history = []
    }

    function removeFromHistory(notifId) {
        const current = Array.isArray(settings.history) ? Array.from(settings.history) : []
        settings.history = current.filter(n => n.id !== notifId)
    }

    function clearActiveNotifications() {
        Qt.callLater(() => {
            const notifs = server.trackedNotifications
            for (let i = notifs.length - 1; i >= 0; i--) {
                notifs[i].expire()
            }
        })
    }

    function serializeNotification(n) {
        return {
            id:      Date.now().toString(36) + Math.random().toString(36).slice(2),
            appName: n.appName  ?? "",
            appIcon: n.appIcon  ?? "",
            summary: n.summary  ?? "",
            body:    n.body     ?? "",
            urgency: n.urgency  ?? 1,
            time:    Date.now()
        }
    }

    PersistentProperties {
        id: settings
        reloadableId: "persitentNotifications"
        property bool dnd: false
        property var history: []
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        inlineReplySupported: true

        onNotification: n => {
            const entry = root.serializeNotification(n)
            const current = Array.isArray(settings.history) ? Array.from(settings.history) : []
            settings.history = [entry, ...current].slice(0, 100)

            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return

            n.tracked = true
        }
    }
}