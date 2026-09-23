// --- Log (módulo JS, .pragma library) ---
// Logger central del shell: todo log pasa por aquí.
// Uso: import "<ruta>/Core/Log.js" as Log  →  Log.info(...) / Log.warn(...)
// Nivel con Log.init("debug"|"info"|"warn"|"error") una vez al arrancar
// (ver shell.qml; lee QS_LOG_LEVEL). Sin init, defecto: info.
// Sin estado QML: funciona desde cualquier .qml o .js.

.pragma library

// 0 debug, 1 info, 2 warn, 3 error.
var _level = 1;

function init(levelName) {
    var v = String(levelName || "").toLowerCase();
    if (v === "debug")
        _level = 0;
    else if (v === "warn" || v === "warning")
        _level = 2;
    else if (v === "error")
        _level = 3;
    else
        _level = 1;
}

function _forward(fn, args) {
    fn.apply(console, args);
}

function debug() {
    if (_level <= 0)
        _forward(console.debug, arguments);
}

function info() {
    if (_level <= 1)
        _forward(console.info, arguments);
}

function warn() {
    if (_level <= 2)
        _forward(console.warn, arguments);
}

function error() {
    _forward(console.error, arguments);
}
