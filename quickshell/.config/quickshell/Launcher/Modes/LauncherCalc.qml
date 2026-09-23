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

    property Timer debounce: Timer {
        interval: 250
        onTriggered: {
            if (!root.active)
                return;
            const q = root.query;
            if (!root.looksLikeCalc(q)) {
                root.result = "";
                root.forQuery = q;
                return;
            }
            // Coma decimal → punto + locale C: igual que antes, punto decimal.
            const expr = q.trim().replace(/,/g, ".");
            root.busy = true;
            root.acc = "";
            calcProc.command = ["env", "LC_ALL=C", "qalc", "-t", expr];
            calcProc.running = true;
        }
    }

    property Process calcProc: Process {
        stdout: SplitParser {
            onRead: data => {
                root.acc += data + "\n";
            }
        }
        onExited: code => {
            root.busy = false;
            const r = root.acc.trim();
            root.result = code === 0 ? r : "";
            root.forQuery = root.query;
        }
    }
}
