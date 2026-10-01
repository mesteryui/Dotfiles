// --- MenuStore = UnifiedMenuStore (Singleton) ---
// SISTEMA ÚNICO de menús personalizados (todo lo que NO es Archivos,
// Aplicaciones, Calculadora, Web, Emojis, Clipboard).
//
// Todo menú —interno o tuyo, estático o dinámico— usa el componente base
// Launcher/MenuDefinition.qml (módulo qs.Launcher) como raíz:
//   sectionId, titleFallback, titleKey, iconName, parentId, entries,
//   helpers, refresh() + fábricas shell()/ipc()/submenu()/entry()
// La base es genérica (no conoce ningún menú concreto); la lógica de cada
// menú vive en su propio archivo. Los dinámicos (p. ej. powerprofiles,
// fastfetch, animations en MenuProviders/System/) generan `entries` en
// refresh() reasignando el array entero, con sus Process/Timer en `helpers`.
//
// Dónde vive cada uno:
//   Launcher/MenuDefinition.qml           → componente base (no es un menú)
//   MenuProviders/System/*.qml        → internos (cargan primero)
//   MenuProviders/*.qml               → tuyos (+ el generador new-menu.sh)
// Todos importan `qs.Launcher` para ver MenuDefinition.
//
// Añadir un menú = soltar un archivo en MenuProviders/ (se aplica al
// abrir el launcher, que comprueba cambios en disco). Quitarlo =
// borrarlo. Sin tocar Registry ni servicios, y sin recargar todo el
// shell. `qs ipc call launcher reloadMenus` fuerza la recarga inmediata.
// (Segunda vía: plugins tipo `launcher` en ~/.config/shinro/plugins,
// gestionados por PluginService; ver PLUGINS.md.)
//
// Reactividad: `revision` se incrementa en cada (re)descubrimiento y el
// Registry lo lee en sus funciones, así los bindings del launcher se
// reevalúan solos al recargar. Los `entries` reasignados en runtime
// (menús dinámicos) ya invalidan los bindings por lectura de propiedad.
//
// Prioridad: si un sectionId tuyo colisiona con uno interno
// (MenuProviders/System/, estático o dinámico), manda el interno y se
// avisa por consola (ver SystemMenuRegistry).
//
// Nota: el descubrimiento es asíncrono al arrancar; si el launcher se abre
// antes de completarse, las secciones aparecen solas al terminar
// (la reasignación de `providers` reevalúa los bindings).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules

Singleton {
    id: root

    readonly property string systemDir: Directories.config + "/quickshell/Launcher/MenuProviders/System"
    readonly property string providersDir: Directories.config + "/quickshell/Launcher/MenuProviders"

    // Internos primero (ganan en colisiones), luego los tuyos.
    // Se reasigna entero al descubrir.
    property var systemProviders: []
    property var userProviders: []
    // Providers de plugins (propiedad de PluginService: este store solo
    // los referencia, nunca los destruye). Ver setPluginProviders().
    property var pluginProviders: []
    property var providers: []

    // Contador de descubrimientos. El Registry lo lee para que los
    // bindings del launcher se reevalúen solos tras un reload().
    property int revision: 0
    // Nº de reloads (rompe la caché de Qt.createComponent en loadOne).
    property int loadEpoch: 0
    // Último descubrimiento con errores: visible vía IPC (`reloadMenus`
    // incluye "errors=N") en vez de solo consola.
    property int loadErrors: 0
    property string lastError: ""

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

    // Registra los providers aportados por plugins (los crea y destruye
    // PluginService; aquí solo se referencian). Sin bump si ni los ids
    // ni los objetos cambian: evita bucles con quien observe revision.
    function setPluginProviders(list) {
        const next = list || [];
        const cur = root.pluginProviders;
        let same = cur.length === next.length;
        if (same) {
            for (let i = 0; i < cur.length; i++)
                if (cur[i] !== next[i]) {
                    same = false;
                    break;
                }
        }
        root.pluginProviders = next;
        if (!same) {
            root.providers = root.systemProviders.concat(root.userProviders).concat(next);
            root.revision += 1;
        }
    }

    Component.onCompleted: discoverProc.running = true

    // --- Recarga en vivo sin polling fijo ---
    // Antes había un Timer que firmaba los directorios cada 2 s. Ahora no
    // hay proceso periódico: la comprobación en disco se hace al abrir el
    // launcher (vía SystemMenuRegistry.refreshAll() → checkNow()) y bajo
    // demanda con `qs ipc call launcher reloadMenus`.
    // Coste: un `stat` por apertura en vez de uno cada 2 s siempre.
    property bool autoReload: true
    property string dirSignature: ""
    property string watchAcc: ""

    // Comprueba ahora (sin esperar a nada). Se llama al abrir el
    // launcher vía SystemMenuRegistry.refreshAll().
    function checkNow() {
        if (root.autoReload && !watchProc.running && !discoverProc.running)
            watchProc.running = true;
    }

    Process {
        id: watchProc

        command: ["sh", "-c",
            "for d in '" + root.systemDir + "' '" + root.providersDir + "'; do " +
            "for f in \"$d\"/*.qml; do [ -f \"$f\" ] || continue; " +
            "stat -c '%n|%Y|%s' \"$f\"; done; done; " +
            "stat -c '%n|%Y|%s' '" + root.providersDir + "/../MenuDefinition.qml' " +
            "2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                root.watchAcc += data + "\n";
            }
        }
        onRunningChanged: {
            if (running)
                root.watchAcc = "";
        }
        onExited: {
            const sig = root.watchAcc;
            if (root.dirSignature === "") {
                root.dirSignature = sig;
                return;
            }
            if (sig !== root.dirSignature) {
                root.dirSignature = sig;
                root.reload();
            }
        }
    }

    // Recarga los menús sin recargar todo el shell:
    //   qs ipc call launcher reloadMenus
    // Re-escanea ambos directorios, destruye los providers viejos, crea
    // los nuevos y refresca los dinámicos. No-op si ya hay un
    // descubrimiento en curso (el resultado en vuelo ya incluye lo último).
    function reload() {
        if (discoverProc.running)
            return false;
        loadEpoch += 1;
        discoverProc.running = true;
        return true;
    }

    // "S:nombre.qml" = MenuProviders/System/, "U:nombre.qml" = MenuProviders/
    property var foundFiles: []

    Process {
        id: discoverProc

        command: ["sh", "-c",
            "for f in '" + root.systemDir + "'/*.qml; do [ -f \"$f\" ] || continue; n=${f##*/}; echo \"S:$n\"; done;" +
            "for f in '" + root.providersDir + "'/*.qml; do [ -f \"$f\" ] || continue; n=${f##*/}; echo \"U:$n\"; done"]
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
        // En reloads se añade "?epoch=" para romper la caché del motor QML:
        // sin esto, editar un provider y recargar devolvería el componente
        // viejo compilado. La query no forma parte de la ruta del fichero
        // local. En el arranque (epoch 0) se usa la URL tal cual.
        const url = base + name + (root.loadEpoch > 0 ? "?epoch=" + root.loadEpoch : "");
        const comp = Qt.createComponent(Qt.resolvedUrl(url));
        if (comp.status !== Component.Ready) {
            root.lastError = base + name + ": " + comp.errorString();
            console.warn("MenuStore: no se pudo cargar " + root.lastError);
            return null;
        }
        const obj = comp.createObject(root, {});
        if (!obj || !obj.sectionId) {
            root.lastError = base + name + " no expone sectionId, se ignora";
            console.warn("MenuStore: " + root.lastError);
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
        let errors = 0;
        for (let i = 0; i < foundFiles.length; i++) {
            const raw = foundFiles[i];
            const tag = raw.slice(0, 1);
            const name = raw.slice(2);
            const obj = loadOne(tag, name);
            if (!obj) {
                errors += 1;
                continue;
            }
            if (seen[obj.sectionId]) {
                root.lastError = "sectionId duplicado '" + obj.sectionId + "' en " + name + ", se ignora (manda el primero)";
                console.warn("MenuStore: " + root.lastError);
                obj.destroy();
                continue;
            }
            seen[obj.sectionId] = true;
            if (tag === "S")
                sys.push(obj);
            else
                usr.push(obj);
        }
        // Todo-o-nada en reloads: si algún fichero falla al compilar y ya
        // había menús, se destruyen los nuevos a medias y se conservan los
        // viejos (mejor menú viejo que menú roto). En el arranque se usa
        // lo que haya, como antes.
        root.loadErrors = errors;
        if (errors > 0 && root.loadEpoch > 0 && root.providers.length > 0) {
            console.warn("MenuStore: " + errors + " provider(s) con error, se conservan los menús actuales");
            for (let d = 0; d < sys.length; d++)
                sys[d].destroy();
            for (let e = 0; e < usr.length; e++)
                usr[e].destroy();
            return;
        }
        // Si el redescubrimiento sale vacío pero había menús, se conservan
        // los viejos (p. ej. error transitorio del ls): mejor menú viejo
        // que ningún menú.
        if (sys.length + usr.length === 0 && root.providers.length > 0) {
            console.warn("MenuStore: redescubrimiento vacío, se conservan los providers actuales");
            return;
        }
        // Limpia providers anteriores (recarga) antes de reasignar.
        // OJO: los de plugins son propiedad de PluginService y se saltan.
        for (let k = 0; k < root.providers.length; k++)
            if (root.pluginProviders.indexOf(root.providers[k]) < 0)
                root.providers[k].destroy();
        root.systemProviders = sys;
        root.userProviders = usr;
        // Internos primero: en colisiones con dinámicos manda el interno
        // (ver SystemMenuRegistry.sections()). Los plugins van últimos:
        // nunca pisan a core ni a usuario.
        root.providers = sys.concat(usr).concat(root.pluginProviders);
        if (errors === 0)
            root.lastError = "";
        // Invalida los bindings que leen menús (ver SystemMenuRegistry).
        root.revision += 1;
        // Los dinámicos propios regeneran sus entries con la nueva instancia.
        root.refreshAll();
    }
}
