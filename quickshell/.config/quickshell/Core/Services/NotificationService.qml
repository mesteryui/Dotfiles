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

    property ListModel historyModel: ListModel {}
    readonly property alias history: root.historyModel

    readonly property alias server: notificationServer

    // Contador monotónico para historyId. No usamos n.id como clave porque
    // el spec de notificaciones de escritorio permite que una app reutilice
    // el mismo id para reemplazar una notificación anterior — dos entradas
    // de historial distintas podrían terminar compartiendo id.
    property int historyIdCounter: 0

    // Tope de historial: en sesiones largas crecía sin fin (cada entrada
    // retiene además su Notification con la imagen). El centro solo
    // muestra las recientes; descartar las más viejas no cambia lo visible.
    readonly property int historyLimit: 100

    // { historyId, notification } por cada entrada que sigue viva en el
    // historial. Es lo que mantiene el objeto Notification (y por lo tanto
    // su .image / el handle image://qsimage/...) sin destruirse mientras
    // siga apareciendo en historyModel. Ver Instantiator más abajo.
    property var retainedForHistory: []

    // Llamar desde el (×) de NotificationHistoryCard en vez de tocar
    // historyModel directamente — así soltamos también el RetainableLock.
    function removeFromHistory(historyId) {
        for (let i = 0; i < root.historyModel.count; i++) {
            if (root.historyModel.get(i).historyId === historyId) {
                root.historyModel.remove(i);
                break;
            }
        }
        root.retainedForHistory = root.retainedForHistory.filter(entry => entry.historyId !== historyId);
    }

    function toggleDnd() {
        props.dnd = !props.dnd;
    }

    // Hora relativa humana ("ahora mismo", "hace 5 min", "ayer").
    // epochSec: segundos Unix (los que guarda el historial).
    function formatRelative(epochSec) {
        const now = Math.floor(Date.now() / 1000);
        const d = Math.max(0, now - (epochSec || 0));
        if (d < 60)
            return I18nService.getTranslation("notifications.time_now", "ahora mismo");
        if (d < 3600) {
            const m = Math.floor(d / 60);
            return I18nService.getTranslation("notifications.time_min_ago", "hace %1 min").arg(m);
        }
        if (d < 86400) {
            const h = Math.floor(d / 3600);
            return I18nService.getTranslation("notifications.time_hour_ago", "hace %1 h").arg(h);
        }
        if (d < 172800)
            return I18nService.getTranslation("notifications.time_yesterday", "ayer");
        return Qt.formatDate(new Date(epochSec * 1000), "d MMM");
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodySupported: true
        imageSupported: true
        actionIconsSupported: true

        onNotification: n => {
            const historyId = root.historyIdCounter++;

            // Las data: URLs (p. ej. imágenes de notificaciones de
            // navegadores) suelen venir truncadas y spamean los
            // decodificadores Qt ("Corrupt JPEG data"): se descartan al
            // icono de la app (misma idea que MprisService._cleanArtUrl).
            // Centralizado aquí cubre toast + centro + historial de una vez.
            let resolvedIcon = String(n.image ?? "");
            if (resolvedIcon.startsWith("data:"))
                resolvedIcon = "";
            if (resolvedIcon === "" && n.appIcon && n.appIcon !== "") {
                resolvedIcon = Quickshell.iconPath(n.appIcon, "image-missing");
            }

            root.historyModel.insert(0, {
                historyId: historyId,
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                urgency: n.urgency,
                time: Qt.formatDateTime(new Date(), "HH:mm"),
                historyEpoch: Math.floor(Date.now() / 1000),
                icon: resolvedIcon || ""
            });

            // Retenemos el objeto vivo mientras siga en el historial: sin esto,
            // Quickshell destruye la notificación al descartarse/expirar y el
            // handle image://qsimage/... detrás de n.image queda huérfano
            // (el WARN "unknown handle" que veías en consola).
            root.retainedForHistory = [...root.retainedForHistory,
                {
                    historyId: historyId,
                    notification: n
                }
            ];

            n.tracked = true;

            // Poda: si se supera el tope, caen las más viejas (están al
            // final porque se inserta por delante). Libera también el
            // RetainableLock vía removeFromHistory.
            while (root.historyModel.count > root.historyLimit) {
                const oldest = root.historyModel.get(root.historyModel.count - 1);
                root.removeFromHistory(oldest.historyId);
            }
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
