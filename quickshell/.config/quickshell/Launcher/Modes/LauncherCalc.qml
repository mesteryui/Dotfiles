// --- LauncherCalc: calculadora del launcher vía libqalculate (qalc) ---
// El cálculo lo hace qalc (-t = salida escueta); aquí solo se decide
// cuándo pedirlo y se guarda el resultado. Sin shell: argv directo.
// AppLauncher aporta query/active y lee result/forQuery/busy para pintar.
// (Extraído de AppLauncher.qml para partir sus ~1400 líneas.)
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string query: ""
    property bool active: false

    property string result: ""
    property string forQuery: ""
    property bool busy: false
    property string acc: ""
    // true si el último intento falló (qalc ausente o error): permite
    // pintar "no disponible" en vez de confundirlo con "no parece cálculo".
    property bool failed: false
    // Cache negativa si qalc no existe: no spamear un proceso por tecla.
    property bool _qalcMissing: false
    property double _qalcRetryAt: 0
    // Query con la que se lanzó el proceso en vuelo (pareja con onExited).
    property string _launchQuery: ""
    // Watchdog: qalc colgado no debe dejar busy=true para siempre.
    property Timer watchdog: Timer {
        interval: 5000
        onTriggered: {
            if (calcProc.running)
                calcProc.running = false;
        }
    }

    // ¿Parece cálculo? Debe llevar dígito y solo caracteres plausibles
    // (números, operadores, unidades, funciones, monedas). El modo calc es
    // explícito (=), así que lo raro lo interpreta qalc como sabe.
    function looksLikeCalc(q) {
        const t = q.trim();
        if (t === "" || !/[0-9]/.test(t))
            return false;
        return /^[\w\s+\-*/%^().,!°√π€$£¥×÷−·'":;<>|&=²³?¡¿-]+$/.test(t);
    }

    onQueryChanged: {
        if (root.active)
            debounce.restart();
    }
    onActiveChanged: {
        if (root.active)
            debounce.restart();
    }

    // Miles con coma ("1,000") se quitan; coma decimal ("1,5") pasa a punto.
    // Antes se convertían todas las comas a puntos y "1,000+2" se rompía.
    function decimalExpr(q) {
        const t = q.trim().replace(/(\d),(\d{3}\b)/g, "$1$2");
        return t.replace(/,/g, ".");
    }

    property Timer debounce: Timer {
        interval: 250
        onTriggered: {
            if (!root.active)
                return;
            const q = root.query;
            if (!root.looksLikeCalc(q)) {
                root.result = "";
                root.forQuery = q;
                root.failed = false;
                return;
            }
            // qalc ausente: cache negativa 30s sin spamear procesos.
            if (root._qalcMissing && Date.now() < root._qalcRetryAt) {
                root.result = "";
                root.forQuery = q;
                root.failed = true;
                return;
            }
            // Coma decimal → punto + locale C: igual que antes, punto decimal.
            const expr = root.decimalExpr(q);
            // Mata el cálculo anterior: si no, su stdout se mezcla con este.
            if (calcProc.running)
                calcProc.running = false;
            root.busy = true;
            root.failed = false;
            root.acc = "";
            root._launchQuery = q;
            calcProc.command = ["env", "LC_ALL=C", "qalc", "-t", expr];
            calcProc.running = true;
            root.watchdog.restart();
        }
    }

    property Process calcProc: Process {
        stdout: SplitParser {
            onRead: data => {
                root.acc += data + "\n";
            }
        }
        onExited: code => {
            root.watchdog.stop();
            root.busy = false;
            // 127 = binario no encontrado: cache negativa + backoff.
            if (code === 127) {
                root._qalcMissing = true;
                root._qalcRetryAt = Date.now() + 30000;
                root.result = "";
                root.failed = true;
                root.forQuery = root._launchQuery;
                return;
            }
            root._qalcMissing = false;
            const r = root.acc.trim();
            root.result = code === 0 ? r : "";
            root.failed = code !== 0;
            // Se publica la query de lanzamiento, no la actual: si el
            // usuario siguió tecleando, AppLauncher la descarta por no
            // coincidir y no pinta un resultado de otra query.
            root.forQuery = root._launchQuery;
        }
    }
}
