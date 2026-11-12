// --- TimeService ---
// Único SystemClock del shell: barra, lockscreen y relativos de notificaciones.
//
// DISEÑO REACTIVO + RELOJ INDEPENDIENTE PARA LOCKSCREEN:
//   * Propiedades reactivas a `date` y `tick`: QML las reevalúa solo cuando
//     cambian sus dependencias (sin polling continuo del hilo principal).
//   * SystemClock (Qt) emite ticks cada minuto: `onDateChanged` actualiza
//     `_now` y el reloj avanza en los bordes de minuto cuando la sesión está
//     desbloqueada.
//   * **Bloqueo de pantalla**: al activarse `LockState.locked`, `forceNow` se
//     activa inmediatamente y `lockTick` empieza a contar cada segundo usando
//     `new Date()` directamente. El lockscreen NO depende de SystemClock ni del
//     hilo QML principal mientras está bloqueado: muestra la hora real exacta.
//   * Al desbloquear: `forceNow` se apaga a los 2 s y vuelve a SystemClock.
//   * Formato fijo 24 h ("HH:mm").

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Cuando true, `date` devuelve new Date() inmediatamente (bloqueo/desbloqueo).
    property bool forceNow: false

    // Fuente de hora efectiva para la sesión desbloqueada. SystemClock escribe
    // aquí vía onDateChanged cada minuto. Usar `var` (no `date`) porque
    // `property date` es read-only en QML y no se puede reasignar.
    property var _now: new Date()

    // Tick de cambio normal (sesión desbloqueada). Se incrementa en eventos
    // reales de resincronización.
    property int tick: 0

    // Tick dedicado al lockscreen: se incrementa cada segundo SOLO mientras
    // la pantalla está bloqueada. Fuerza a timeText/barText a reevaluarse
    // usando new Date() directamente, independientemente de SystemClock.
    property int lockTick: 0

    readonly property date date: forceNow ? new Date() : _now
    readonly property int hours: root.date.getHours()
    readonly property int minutes: root.date.getMinutes()
    readonly property int seconds: root.date.getSeconds()

    readonly property var locale: I18nService.locale

    // Barra: "mar 14:32". Binding reactivo: depende de `tick` para forzar
    // reevaluación cuando cambie el tiempo. Cuando forceNow está activo
    // (pantalla bloqueada), lee de new Date() directamente.
    readonly property string barText: root.formatBarText() + (root.tick !== undefined ? "" : "")

    function pad(n) { return n < 10 ? "0" + n : n; }

    function formatBarText() {
        var d = root.date;
        var wd = d.toLocaleDateString(root.locale, "ddd");
        return wd + " " + root.pad(d.getHours()) + ":" + root.pad(d.getMinutes());
    }

    readonly property string weekdayText: root.date.toLocaleDateString(root.locale, "ddd")

    // Contador de resincronizaciones forzadas (depuración).
    property int resyncCount: 0

    // Señal emitida cuando el tiempo se resincroniza.
    signal timeChanged()

    // Lockscreen: propiedad QML reactiva (no función JS). Lee de new Date()
    // directamente cuando está bloqueado (forceNow), independientemente de
    // SystemClock. Depende de lockTick para forzar reevaluación cada segundo
    // durante el bloqueo.
    readonly property string timeText: root.formatTimeText() + (root.lockTick !== undefined ? "" : "")

    function formatTimeText() {
        var d = root.date;
        return root.pad(d.getHours()) + ":" + root.pad(d.getMinutes());
    }

    function timeString(fmt) {
        if (!fmt) {
            return root.pad(root.date.getHours()) + ":" + root.pad(root.date.getMinutes());
        }
        return root.date.toLocaleTimeString(root.locale, fmt);
    }

    function dateString(fmt) {
        return root.date.toLocaleDateString(root.locale, fmt);
    }

    // SystemClock actualiza _now cada minuto (sesión desbloqueada).
    Connections {
        target: clock
        function onDateChanged() {
            if (!root.forceNow && clock.date && !isNaN(clock.date.getTime())) {
                root._now = clock.date;
                root.tick = root.tick + 1;
                root.timeChanged();
            }
        }
    }

    // ---- Reloj independiente del lockscreen (corre solo cuando está bloqueado) ----
    Timer {
        id: lockscreenTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root._now = new Date();
            root.lockTick = root.lockTick + 1;
            root.timeChanged();
        }
    }

    // Red de seguridad silenciosa para sesión desbloqueada: cada 30 s corrige
    // si _now se desvió más de 30 s del tiempo real.
    Timer {
        id: driftGuardTimer
        interval: 30000
        repeat: true
        running: false
        onTriggered: root.checkDrift()
    }

    // Último recurso para sesión desbloqueada: cada 60 s fuerza resincronización.
    Timer {
        id: forcedResyncTimer
        interval: 60000
        repeat: true
        running: false
        onTriggered: {
            root._now = new Date();
            root.resyncCount = root.resyncCount + 1;
            root.tick = root.tick + 1;
            root.timeChanged();
        }
    }

    function checkDrift() {
        var now = new Date();
        var diff = Math.abs(now.getTime() - root._now.getTime());
        if (diff > 30000) {
            root._now = now;
            root.resyncCount = root.resyncCount + 1;
            root.tick = root.tick + 1;
            root.timeChanged();
        }
    }

    function refreshNow() {
        root._now = new Date();
        root.tick = root.tick + 1;
        root.timeChanged();
    }

    Component.onCompleted: {
        root._now = new Date();
        root.tick = 0;
        // Si la pantalla ya está bloqueada al inicializar el singleton,
        // `lockedChanged` no se disparará (no hay transición), así que
        // activamos forceNow y el timer del lockscreen aquí directamente.
        if (LockState.locked && root.lockscreenTimer) {
            root.forceNow = true;
            root._now = new Date();
            root.lockTick = 0;
            root.tick = root.tick + 1;
            root.lockscreenTimer.start();
            root.timeChanged();
        }
    }

    // ---- Gestión de bloqueo/desbloqueo ----
    Connections {
        target: LockState
        function onLockedChanged() {
            if (LockState.locked) {
                // PANTALLA BLOQUEADA: activar forceNow inmediatamente y usar
                // new Date() directamente. Iniciar timer independiente del
                // lockscreen para que el reloj no se quede atrancado aunque
                // SystemClock deje de entregar ticks.
                root.forceNow = true;
                root._now = new Date();
                root.tick = root.tick + 1;
                root.lockTick = 0;
                if (root.lockscreenTimer) {
                    root.lockscreenTimer.start();
                }
                root.timeChanged();
            } else {
                // PANTALLA DESBLOQUEADA: parar timer del lockscreen, apagar
                // forceNow a los 2 s y volver a SystemClock.
                if (root.lockscreenTimer) {
                    root.lockscreenTimer.stop();
                }
                root.lockTick = 0;
                root.forceNow = true;
                root._now = new Date();
                root.tick = root.tick + 1;
                root.timeChanged();
                if (root.resetForceNow) {
                    root.resetForceNow.restart();
                }
            }
        }
    }

    Timer {
        id: resetForceNow
        interval: 2000
        repeat: false
        onTriggered: {
            root.forceNow = false;
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
