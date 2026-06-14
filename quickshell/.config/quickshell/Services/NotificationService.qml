// Services/NotificationService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Lista de notificaciones activas
    property var notifications: []
    readonly property int unreadCount: {
        let count = 0;
        for (const n of notifications) {
            if (!n._read) count++;
        }
        return count;
    }

    // Tiempo por defecto antes de expirar (ms). 0 = no expira
    property int defaultTimeout: 5000

    NotificationServer {
        id: server

        // Permisos que aceptamos de las apps
        keepOnReload: true          // sobrevive al hot-reload
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (notif) => {
            // Añade metadatos propios
            notif._timestamp = Date.now();
            notif._read = false;

            root.notifications = [notif, ...root.notifications];

            // Auto-expirar si la notif pide timeout o usamos el default
            const timeout = notif.expireTimeout > 0
                ? notif.expireTimeout
                : root.defaultTimeout;

            if (timeout > 0) {
                expireTimer.createTimer(notif, timeout);
            }

            // Señal hacia afuera para que el popup reaccione
            root.notificationAdded(notif);
        }
    }

    // Señales públicas
    signal notificationAdded(var notif)
    signal notificationRemoved(int id)
    signal allCleared()

    // --- API pública ---

    function dismiss(notif) {
        notif.dismiss();
        _remove(notif.id);
    }

    function dismissAll() {
        for (const n of notifications) n.dismiss();
        notifications = [];
        allCleared();
    }

    function markRead(notif) {
        notif._read = true;
        // Forzar refresco del binding
        notifications = [...notifications];
    }

    function markAllRead() {
        notifications.forEach(n => n._read = true);
        notifications = [...notifications];
    }

    function invokeAction(notif, actionId) {
        notif.invokeAction(actionId);
        _remove(notif.id);
    }

    // --- Interno ---

    function _remove(id) {
        notifications = notifications.filter(n => n.id !== id);
        notificationRemoved(id);
    }

    // Gestor de timers de expiración
    QtObject {
        id: expireTimer

        function createTimer(notif, ms) {
            const t = timerComponent.createObject(root, { interval: ms });
            t.triggered.connect(() => {
                root._remove(notif.id);
                t.destroy();
            });
            t.start();
        }
    }

    Component {
        id: timerComponent
        Timer { repeat: false }
    }
}