// .pragma library
// Utilidad compartida del Launcher: escape para incrustar texto arbitrario
// en comandos `sh -c '...'`.
//
// Es la ÚNICA implementación en el módulo qs.Launcher (la usan
// AppLauncher vía ClipboardService.copyText, EmojiService, FilePreviewService
// y los providers dinámicos). Core/Services/ClipboardService conserva su
// copia local a propósito: Core no debe depender de Launcher.
//
// Semántica (no cambiar sin revisar todos los usos):
//   shellEscape("a'b") === "a'\\''b"
// es decir, cierra la comilla simple, mete una escapada y reabre.

.pragma library

function shellEscape(s) {
    return String(s).replace(/'/g, "'\\''");
}
