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

    signal notificationReceived(var notification)

    function toggleDnd() {
        settings.dnd = !settings.dnd
    }

    function clearHistory() {
        settings.history = []
    }

    function removeFromHistory(notifId) {
        const current = Array.isArray(settings.history) ? Array.from(settings.history) : []
        settings.history = current.filter(n => n.id !== notifId)
    }

    function dismissActiveNotification(notifId) {
        Qt.callLater(() => {
            const notifs = server.trackedNotifications
            for (let i = 0; i < notifs.length; i++) {
                if (notifs[i].id === notifId) {
                    notifs[i].dismiss()
                    break
                }
            }
        })
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
            image:   n.image    ?? "",
            time:    Date.now()
        }
    }

    function sendTestNotification(summary, body, urgency) {
        const entry = {
            id:      "test_" + Date.now().toString(36) + Math.random().toString(36).slice(2),
            appName: "Test System",
            appIcon: "dialog-information",
            summary: summary ?? "Notificación de Prueba",
            body:    body ?? "Esto es una notificación para verificar que todo funciona correctamente.",
            urgency: urgency ?? 1,
            image:   "",
            time:    Date.now()
        }
        const current = Array.isArray(settings.history) ? Array.from(settings.history) : []
        settings.history = [entry, ...current].slice(0, 100)
        root.notificationReceived(entry)
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
            root.notificationReceived(entry)

            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return

            n.tracked = true
        }
    }
}