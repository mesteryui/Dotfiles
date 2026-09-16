// --- CustomMenuService = UnifiedMenuStore (Singleton) ---
// SISTEMA ÚNICO de menús personalizados (todo lo que NO es Archivos,
// Aplicaciones, Calculadora, Web, Emojis, Clipboard).
//
// Todo menú —interno o tuyo, estático o dinámico— es un provider QML con la
// misma interfaz de MenuProviders/MenuProvider.qml:
//   sectionId, titleFallback, titleKey, iconName, parentId, entries, refresh()
//
// Dónde vive cada uno (TODO bajo MenuProviders/):
//   MenuProviders/System/*.qml → internos (misma interfaz, cargan primero)
//   MenuProviders/*.qml         → tuyos (salvo plantilla MenuProvider.qml
//                                y el generador new-menu.sh)
//
// Añadir un menú = soltar un archivo en MenuProviders/ y recargar el shell.
// Quitarlo = borrarlo. Sin tocar Registry ni servicios.
//
// Prioridad: si un sectionId tuyo colisiona con uno interno o dinámico,
// manda el interno y se avisa por consola (ver SystemMenuRegistry).
//
// Nota: el descubrimiento es asíncrono al arrancar; si el launcher se abre
// antes de completarse, las secciones aparecen solas al terminar
// (la reasignación de `providers` reevalúa los bindings).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string systemDir: Quickshell.env("HOME") + "/.config/quickshell/Launcher/MenuProviders/System"
    readonly property string providersDir: Quickshell.env("HOME") + "/.config/quickshell/Launcher/MenuProviders"

    // Internos primero (ganan en colisiones), luego los tuyos.
    // Se reasigna entero al descubrir.
    property var systemProviders: []
    property var userProviders: []
    property var providers: []

    // true si el sectionId lo aporta un menú interno (MenuProviders/System/).
    function isSystemSection(sectionId) {
        for (let i = 0; i < systemProviders.length; i++)
            if (systemProviders[i].sectionId === sectionId)
                return true;
        return false;
    }

    function providerFor(sectionId) {
        for (let i = 0; i < providers.length; i++)
            if (providers[i].sectionId === sectionId)
                return providers[i];
        return null;
    }

    function sectionInfos() {
        const out = [];
        for (let i = 0; i < providers.length; i++) {
            const p = providers[i];
            out.push({
                sectionId: p.sectionId,
                titleFallback: p.titleFallback,
                titleKey: p.titleKey,
                iconName: p.iconName,
                parentId: p.parentId
            });
        }
        return out;
    }

    function entriesOf(sectionId) {
        const p = providerFor(sectionId);
        return p ? (p.entries || []) : [];
    }

    // Refresca una sección (no-op si no es de un provider).
    // Se llama siempre, sin distinguir estático de dinámico: en los
    // estáticos refresh() es vacío por defecto.
    function refreshSection(sectionId) {
        const p = providerFor(sectionId);
        if (p && typeof p.refresh === "function")
            p.refresh();
    }

    function refreshAll() {
        for (let i = 0; i < providers.length; i++)
            if (typeof providers[i].refresh === "function")
                providers[i].refresh();
    }

    Component.onCompleted: discoverProc.running = true

    // "S:nombre.qml" = MenuProviders/System/, "U:nombre.qml" = MenuProviders/
    property var foundFiles: []

    Process {
        id: discoverProc

        command: ["sh", "-c",
            "for f in '" + root.systemDir + "'/*.qml; do [ -f \"$f\" ] || continue; n=${f##*/}; echo \"S:$n\"; done;" +
            "for f in '" + root.providersDir + "'/*.qml; do [ -f \"$f\" ] || continue; n=${f##*/}; [ \"$n\" = MenuProvider.qml ] && continue; echo \"U:$n\"; done"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line !== "")
                    root.foundFiles.push(line);
            }
        }
        onRunningChanged: {
            if (running)
                root.foundFiles = [];
        }
        onExited: code => root.instantiate()
    }

    function loadOne(tag, name) {
        const base = tag === "S" ? "MenuProviders/System/" : "MenuProviders/";
        const comp = Qt.createComponent(Qt.resolvedUrl(base + name));
        if (comp.status !== Component.Ready) {
            console.warn("CustomMenuService: no se pudo cargar " + base + name + ": " + comp.errorString());
            return null;
        }
        const obj = comp.createObject(root, {});
        if (!obj || !obj.sectionId) {
            console.warn("CustomMenuService: " + base + name + " no expone sectionId, se ignora");
            if (obj)
                obj.destroy();
            return null;
        }
        return obj;
    }

    function instantiate() {
        const sys = [];
        const usr = [];
        const seen = {};
        for (let i = 0; i < foundFiles.length; i++) {
            const raw = foundFiles[i];
            const tag = raw.slice(0, 1);
            const name = raw.slice(2);
            const obj = loadOne(tag, name);
            if (!obj)
                continue;
            if (seen[obj.sectionId]) {
                console.warn("CustomMenuService: sectionId duplicado '" + obj.sectionId + "' en " + name + ", se ignora (manda el primero)");
                obj.destroy();
                continue;
            }
            seen[obj.sectionId] = true;
            if (tag === "S")
                sys.push(obj);
            else
                usr.push(obj);
        }
        // Limpia providers anteriores (recarga) antes de reasignar.
        for (let k = 0; k < root.providers.length; k++)
            root.providers[k].destroy();
        root.systemProviders = sys;
        root.userProviders = usr;
        // Internos primero: en colisiones con dinámicos manda el interno
        // (ver SystemMenuRegistry.sections()).
        root.providers = sys.concat(usr);
    }
}
