// --- MenuDefinition: base genérica de TODO menú personalizado ---
// Úsalo como raíz de tu provider. Vive en Launcher/ (módulo qs.Launcher),
// así que TODO menú lo importa igual:
//   import qs.Launcher
//   MenuDefinition {
//     ...
//   }
//
// Esta base NO sabe nada de ningún menú concreto (ni energía, ni
// fastfetch, ni hyprland, ni nada): solo expone el contrato
// (sectionId/titleFallback/titleKey/iconName/parentId/entries/refresh())
// y fábricas genéricas para construir entradas. Toda la lógica de lo que
// muestra/hace un menú vive en SU propio archivo (ver MenuProviders/).
//
// REGLA DE ORO: aquí se DECLARA una vez; en cada menú se ASIGNA a secas
// (sectionId: "x", entries: [...]). NO redeclares con `property` en el
// menú: QML lo rechaza (Duplicate property name) y el provider no carga.
// Las fábricas (shell/ipc/submenu/entry) se llaman sin cualificar dentro
// de `entries:`; desde objetos anidados usa `root.shell(...)`.
//
// Mínimo (MenuProviders/MiMenu.qml):
//   import qs.Launcher
//   MenuDefinition {
//     sectionId: "mimenu"          // único, sin espacios
//     titleFallback: "Mi menú"
//     entries: [
//       shell("web", "Abrir web", "mi portafolio", "open_in_new", "xdg-open https://ejemplo.com"),
//       submenu("cli", "Cliente X", "submenú", "arrow_forward", "cliente-x"),
//       ipc("keys", "Atajos", "ver cheatsheet", "keyboard", "cheatsheet toggle")
//     ]
//   }
//
// Fábricas (todas aceptan `opts` opcional {titleKey, subtitleKey, preview}):
//   shell(entryId, title, sub, icon, cmd, opts)      → ejecuta en sh
//   ipc(entryId, title, sub, icon, call, opts)       → `qs ipc call ...`
//   submenu(entryId, title, sub, icon, target, opts) → navega a otra sección
//   entry(entryId, title, sub, icon, action, opts)   → control total
// donde action es { kind: "shell", shellCommand } / { kind: "ipc", ipcCall }
// / { kind: "section", targetSectionId } y opts.preview es ruta a imagen
// para el preview lateral. Sin opts se usan los literales en español.
//
// Menú dinámico: genera `entries` en refresh() reasignando el array entero.
// Los trabajadores (Process, Timer…) van en `helpers`, NO como hijos
// directos: la raíz es un QtObject y no admite hijos declarativos.
// Ejemplo dinámico mínimo (ver MenuProviders/System/FastfetchMenu.qml):
//   helpers: [ Process { id: listProc; ... onExited: root.entries = [...] } ]
//   function refresh() { listProc.running = true; }
// Reasignación entera de `entries` al terminar, nunca push parcial.

import QtQuick
import "../Core/Log.js" as Log

QtObject {
    id: root

    property string sectionId: ""
    property string titleFallback: "Menú"
    property string titleKey: ""
    property string iconName: "menu"
    property string parentId: "main"

    // Items con el esquema de arriba. Si dependen del sistema, se generan
    // en refresh() reasignando el array entero al terminar; si son fijos,
    // basta con fijar esta propiedad y no implementar refresh().
    property var entries: []

    // Trabajadores del menú (Process, Timer…) para los menús dinámicos.
    // La raíz es un QtObject (sin default property), así que los objetos
    // de apoyo se declaran aquí y no como hijos directos.
    property list<QtObject> helpers

    // Regenera `entries`. Se llama al abrir el launcher y al entrar en la
    // sección. En los menús fijos se deja vacío (es no-op).
    function refresh() {
    }

    Component.onCompleted: {
        if (root.sectionId === "")
            Log.warn("MenuDefinition: sectionId vacío, el menú se ignorará");
    }

    function entry(entryId, title, sub, icon, action, opts) {
        const o = opts || {};
        return {
            entryId: entryId,
            titleFallback: title, titleKey: o.titleKey || "",
            subtitleFallback: sub, subtitleKey: o.subtitleKey || "",
            iconName: icon || "menu",
            action: action,
            previewPath: o.preview || ""
        };
    }

    function shellCmd(cmd) {
        return { kind: "shell", shellCommand: cmd };
    }

    function ipcCall(call) {
        return { kind: "ipc", ipcCall: call };
    }

    function goSection(target) {
        return { kind: "section", targetSectionId: target };
    }

    function shell(entryId, title, sub, icon, cmd, opts) {
        return root.entry(entryId, title, sub, icon, root.shellCmd(cmd), opts);
    }

    function ipc(entryId, title, sub, icon, call, opts) {
        return root.entry(entryId, title, sub, icon, root.ipcCall(call), opts);
    }

    function submenu(entryId, title, sub, icon, target, opts) {
        return root.entry(entryId, title, sub, icon, root.goSection(target), opts);
    }
}
