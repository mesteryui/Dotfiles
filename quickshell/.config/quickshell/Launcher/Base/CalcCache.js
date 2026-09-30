// --- CalcCache: stale-while-revalidate para el modo calc ---
// Guarda el último resultado mostrado + query que lo produjo, y lo
// devuelve mientras el query pendiente desciende de él (tec peculiar:
// "12" -> "12m"). Vive en .pragma library (estado JS NO reactivo) a
// propósito: si estuviera en props QML, el binding `results` lo leería
// y escribiría en la misma evaluación y QML detectaría binding loop.
.pragma library

var _shown = [];
var _shownFor = "";

function get(q) {
    var t = (q || "").trim();
    if (t === "" || _shown.length === 0)
        return null;
    if (t.startsWith(_shownFor) || _shownFor.startsWith(t))
        return _shown;
    return null;
}

function set(q, arr) {
    _shown = arr;
    _shownFor = q;
    return arr;
}
