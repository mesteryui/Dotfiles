// --- TimeService ---
// Único SystemClock del shell (precisión minutos): la barra, el lockscreen
// y los relativos de notificaciones leen de aquí en vez de crear relojes o
// temporizadores propios (un solo wakeup/min en vez de N).
// Formato fijo 24 h ("hh:mm"), como siempre.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Fecha/hora actuales y sus partes, para saludos y lógica (sin formatear).
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes

    readonly property var locale: I18nService.locale

    // Barra: "mar 14:32".
    readonly property string barText: root.date.toLocaleDateString(root.locale, "ddd") + " " + root.timeString()

    function timeString(fmt) {
        return root.date.toLocaleTimeString(root.locale, fmt || "hh:mm");
    }

    function dateString(fmt) {
        return root.date.toLocaleDateString(root.locale, fmt);
    }

    SystemClock {
        id: clock

        // Minutos: nadie pinta segundos; Seconds despertaría 60x/min
        // para el mismo texto visible.
        precision: SystemClock.Minutes
    }
}
