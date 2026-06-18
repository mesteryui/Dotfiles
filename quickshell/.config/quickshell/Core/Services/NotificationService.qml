// Services/NotificationService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    property alias dnd: settings.dnd
    
    // Acceso directo al modelo nativo de Quickshell
    readonly property alias notifications: server.trackedNotifications
    
    PersistentProperties {
        id: settings
        property bool dnd: false
        property var meta: ({})
    }

    readonly property int unreadCount: {
        let count = 0;
        for (let i = 0; i < notifications.count; i++) {
            const notif = notifications.get(i);
            if (notif && !isRead(notif.id)) count++;
        }
        return count;
    }

    NotificationServer {
        id: server

        // Forzar persistencia y capacidades completas para mejor integración con el OS
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        
        // Añadir estas para máxima compatibilidad
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        inlineReplySupported: true

        Component.onCompleted: {
            console.log("[NotificationServer] Iniciado y escuchando en org.freedesktop.Notifications");
        }

        onNotification: (notif) => {
            console.log("[NotificationServer] Nueva notificación de:", notif.appName, "| Resumen:", notif.summary);
            
            // Inicializar metadatos para la nueva notificación
            const newMeta = Object.assign({}, settings.meta);
            newMeta[notif.id] = { 
                read: false, 
                timestamp: Date.now() 
            };
            settings.meta = newMeta;

            // Emitimos la señal para el popup de toasts
            root.notificationAdded(notif);
        }
    }

    // Señales públicas
    signal notificationAdded(var notif)
    signal allCleared()

    // --- API pública ---

    function isRead(id) {
        return settings.meta[id] ? settings.meta[id].read : false;
    }

    function getTimestamp(id) {
        return settings.meta[id] ? settings.meta[id].timestamp : Date.now();
    }

    function dismiss(notif) {
        if (notif) {
            console.log("[NotificationService] Descartando notificación:", notif.id);
            notif.dismiss();
        }
    }

    function dismissAll() {
        console.log("[NotificationService] Descartando todas las notificaciones");
        while (notifications.count > 0) {
            const n = notifications.get(0);
            if (n) n.dismiss();
            else break;
        }
        settings.meta = {};
        allCleared();
    }

    function markRead(notif) {
        if (!notif) return;
        const newMeta = Object.assign({}, settings.meta);
        if (!newMeta[notif.id]) newMeta[notif.id] = { timestamp: Date.now() };
        newMeta[notif.id].read = true;
        settings.meta = newMeta;
    }

    function markAllRead() {
        const newMeta = Object.assign({}, settings.meta);
        for (let i = 0; i < notifications.count; i++) {
            const n = notifications.get(i);
            if (!n) continue;
            const id = n.id;
            if (!newMeta[id]) newMeta[id] = { timestamp: Date.now() };
            newMeta[id].read = true;
        }
        settings.meta = newMeta;
    }

    function invokeAction(notif, actionId) {
        if (notif) {
            console.log("[NotificationService] Invocando acción:", actionId, "en notif:", notif.id);
            notif.invokeAction(actionId);
        }
    }
}
