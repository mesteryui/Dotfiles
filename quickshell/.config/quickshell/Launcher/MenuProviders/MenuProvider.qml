// --- MenuProvider = plantilla del SISTEMA ÚNICO de menús personalizados ---
// Personalizado = todo lo que NO es Archivos, Aplicaciones, Calculadora,
// Web, Emojis, Clipboard. Esos 6 son modos fijos (ver MenuModes.js) y no se
// crean aquí; todo lo demás (secciones del menú ">" de sistema) sí.
//
// ÚNICA VÍA para crear un menú:
//   1. copia este archivo a Launcher/MenuProviders/MiMenu.qml,
//      (o ejecuta: Launcher/MenuProviders/new-menu.sh MiMenu "Mi menú")
//   2. rellena las propiedades y (si es dinámico) refresh(),
//   3. recarga el shell: el menú aparece solo, sin tocar nada más.
//
// Los menús internos (MenuProviders/System/*.qml) usan EXACTAMENTE esta misma
// interfaz; el Registry no distingue origen. Tu menú cuelga de `parentId`
// (por defecto bajo "Sistema"/main) y usa el mismo esquema semántico;
// además acepta `previewPath` opcional (ruta a imagen) para el preview.
//
// Esquema de cada item de `entries`:
//   { entryId, titleFallback, titleKey, subtitleFallback, subtitleKey,
//     iconName, action, previewPath }
// donde action es:
//   { kind: "shell", shellCommand: "..." }   → ejecuta en sh
//   { kind: "ipc", ipcCall: "cheatsheet toggle" } → qs ipc call ...
//   { kind: "section", targetSectionId: "..." }   → navega a otra sección
//
// titleKey/subtitleKey pueden ser "" (se usa el fallback literal).
// Menú estático: basta con fijar `entries`.
// Menú que depende del sistema: genera `entries` en refresh()
// (reasigna el array entero al terminar, no lo mutes por partes).

import QtQuick

QtObject {
    id: root

    property string sectionId: "mimenu"
    property string titleFallback: "Mi menú"
    property string titleKey: ""
    property string iconName: "menu"
    property string parentId: "main"

    // Items con el esquema de arriba. Si dependen del sistema, se generan
    // en refresh() reasignando el array entero al terminar; si son fijos,
    // basta con fijar esta propiedad y no implementar refresh().
    property var entries: []

    // Regenera `entries`. Se llama al abrir el launcher y al entrar en la
    // sección. En los menús fijos se deja vacío (es no-op).
    function refresh() {
    }
}
