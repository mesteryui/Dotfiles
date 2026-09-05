pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool centerOpen: false
    property alias dnd: props.dnd


    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifications"
    }

    readonly property alias history: historyModel

    readonly property alias server: notificationServer

    // Contador monotónico para historyId. No usamos n.id como clave porque
    // el spec de notificaciones de escritorio permite que una app reutilice
    // el mismo id para reemplazar una notificación anterior — dos entradas
    // de historial distintas podrían terminar compartiendo id.
    property int historyIdCounter: 0

    // { historyId, notification } por cada entrada que sigue viva en el
    // historial. Es lo que mantiene el objeto Notification (y por lo tanto
    // su .image / el handle image://qsimage/...) sin destruirse mientras
    // siga apareciendo en historyModel. Ver Instantiator más abajo.
    property var retainedForHistory: []

    // Llamar desde el (×) de NotificationHistoryCard en vez de tocar
    // historyModel directamente — así soltamos también el RetainableLock.
    function removeFromHistory(historyId) {
        for (let i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).historyId === historyId) {
                historyModel.remove(i);
                break;
            }
        }
        root.retainedForHistory = root.retainedForHistory.filter(entry => entry.historyId !== historyId);
    }

    function toggleDnd() {
        props.dnd = !props.dnd;
    }

    onDndChanged: {
        if (dnd && notificationServer.trackedNotifications) {
            const list = notificationServer.trackedNotifications;
            const count = list.count !== undefined ? list.count : list.length;
            for (let i = count - 1; i >= 0; i--) {
                let n = list.get ? list.get(i) : list[i];
                if (n && n.urgency !== NotificationUrgency.Critical) {
                    n.dismiss();
                }
            }
        }
    }

    ListModel {
        id: historyModel
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodySupported: true
        imageSupported: true
        actionIconsSupported: true

        onNotification: n => {
            const historyId = root.historyIdCounter++;

            let resolvedIcon = n.image;
            if ((!resolvedIcon || resolvedIcon === "") && n.appIcon && n.appIcon !== "") {
                resolvedIcon = Quickshell.iconPath(n.appIcon, "image-missing");
            }

            historyModel.insert(0, {
                historyId: historyId,
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                urgency: n.urgency,
                time: Qt.formatDateTime(new Date(), "HH:mm"),
                icon: resolvedIcon || ""
            });

            // Retenemos el objeto vivo mientras siga en el historial: sin esto,
            // Quickshell destruye la notificación al descartarse/expirar y el
            // handle image://qsimage/... detrás de n.image queda huérfano
            // (el WARN "unknown handle" que veías en consola).
            root.retainedForHistory = [...root.retainedForHistory, {
                historyId: historyId,
                notification: n
            }];

            
            n.tracked = true;
        }
    }

    // Un RetainableLock vivo por cada notificación retenida para el historial.
    // Al sacar una entrada de retainedForHistory (removeFromHistory), el
    // Instantiator destruye su delegate y el lock se libera solo — así no
    // hay que gestionar lock()/unlock() a mano ni arriesgarse a un leak.
    Instantiator {
        model: root.retainedForHistory
        delegate: RetainableLock {
            required property var modelData

            object: modelData.notification
            locked: true
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }

        function show(): void {
            root.centerOpen = true;
        }

        function hide(): void {
            root.centerOpen = false;
        }

        function dndToggle() {
            root.toggleDnd();
        }
    }
}
