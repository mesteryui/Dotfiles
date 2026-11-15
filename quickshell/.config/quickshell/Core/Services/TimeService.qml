// --- TimeService ---
// Único SystemClock del shell: el saludo del lockscreen (LockAuthView) y
// los relativos del historial de notificaciones (NotificationHistoryCard).
//
// DISEÑO REACTIVO, SIN TIMERS PROPIOS:
//   * SystemClock (Qt) emite un tick por minuto: `onDateChanged` escribe
//     `_now` y las bindings que leen `date`/`hours` se reevalúan solas, sin
//     polling del hilo QML principal.
//   * En la transición de bloqueo/desbloqueo se refresca `_now` al
//     instante: en ese momento `date` debe ser exacta y no la del tick
//     anterior (el saludo y los relativos no notan el minuto de resto).
//   * El reloj VISIBLE del lockscreen no pasa por aquí: LockScreenClock
//     tiene su propio SystemClock (precisión minutos), igual que la barra
//     (Bar/Content/ClockContent.qml). Este singleton solo aporta hora
//     reactiva a quien no quiere crear otro reloj.
//
// NOTA: aquí no hace falta un "reloj independiente" mientras está
// bloqueado. SystemClock sigue entregando ticks con la pantalla bloqueada
// (lo demuestra el propio LockScreenClock), así que basta con `_now`.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Fuente de hora efectiva. SystemClock escribe aquí cada minuto. Usar
    // `var` (no `date`) porque `property date` es read-only en QML y no se
    // puede reasignar.
    property var _now: new Date()

    readonly property date date: _now

    readonly property int hours: _now.getHours()

    // Refresco inmediato al cambiar de estado de bloqueo: SystemClock solo
    // entrega un tick por minuto y en esa transición `date` debe ser
    // exacta (saludo del lockscreen, relativos del historial).
    Connections {
        target: LockState

        function onLockedChanged() {
            root._now = new Date();
        }
    }

    // SystemClock actualiza _now cada minuto.
    Connections {
        target: clock

        function onDateChanged() {
            if (clock.date && !isNaN(clock.date.getTime()))
                root._now = clock.date;
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
