pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell

// NotificationData: el DATO de notificaciones (sin fuente ni UI).
// NotificationService (fuente: NotificationServer) empuja aquí vía pushHistory().
// Los consumidores leen este singleton: history, dnd, formatRelative...
Singleton {
    id: root

    property alias dnd: props.dnd
    property ListModel historyModel: ListModel {}
    readonly property alias history: root.historyModel

    // Contador monotónico para historyId. No usamos n.id como clave porque
    // el spec de notificaciones de escritorio permite que una app reutilice
    // el mismo id para reemplazar una notificación anterior — dos entradas
    // de historial distintas podrían terminar compartiendo id.
    property int historyIdCounter: 0

    // Tope de historial: en sesiones largas crecía sin fin. El centro solo
    // muestra las recientes; descartar las más viejas no cambia lo visible.
    readonly property int historyLimit: 100

    // Entrada normalizada al historial (la llama la fuente). Guarda solo
    // texto + icono de la app: retener el objeto Notification mantenía
    // vivas sus imágenes (capturas de 5–20 MB cada una) hasta 100 entradas.
    function pushHistory(n) {
        const historyId = root.historyIdCounter++;

        // El historial no guarda la imagen destacada: el toast la muestra
        // mientras está vivo, pero para el historial basta el icono de la
        // app. Las data: URLs truncadas de los navegadores también se evitan.
        let resolvedIcon = "";
        if (n.appIcon && n.appIcon !== "")
            resolvedIcon = Quickshell.iconPath(n.appIcon, "image-missing");

        root.historyModel.insert(0, {
                                     historyId: historyId,
                                     summary: n.summary,
                                     body: n.body,
                                     appName: n.appName,
                                     urgency: n.urgency,
                                     time: Qt.formatDateTime(new Date(), "HH:mm"),
                                     historyEpoch: Math.floor(Date.now() / 1000),
                                     icon: resolvedIcon
                                 });

        // Poda: si se supera el tope, caen las más viejas (están al
        // final porque se inserta por delante).
        while (root.historyModel.count > root.historyLimit) {
            const oldest = root.historyModel.get(root.historyModel.count - 1);
            root.removeFromHistory(oldest.historyId);
        }
    }

    // Llamar desde el (×) de NotificationHistoryCard en vez de tocar
    // historyModel directamente.
    function removeFromHistory(historyId) {
        for (let i = 0; i < root.historyModel.count; i++) {
            if (root.historyModel.get(i).historyId === historyId) {
                root.historyModel.remove(i);
                break;
            }
        }
    }

    // Vacía el historial.
    function clearHistory() {
        root.historyModel.clear();
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

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifications"
    }
}
