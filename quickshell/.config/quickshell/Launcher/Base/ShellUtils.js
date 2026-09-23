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

// file:// seguro para Image.source: codifica cada segmento para que
// '#', '?', espacios o '%' en el nombre no se parseen como fragmento,
// query o escape de la URL (ver AppLauncher y SystemMenuRegistry).
function fileUrl(path) {
    const p = String(path ?? "");
    if (p === "")
        return "";
    return "file://" + p.split("/").map(encodeURIComponent).join("/");
}
