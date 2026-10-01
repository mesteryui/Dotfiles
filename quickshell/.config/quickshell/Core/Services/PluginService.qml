// --- PluginService (Singleton) ---
// Sistema de plugins de shinro (ver PLUGINS.md + plugin-schema.json).
// Descubrimiento, validación, ciclo de vida (enable/disable),
// persistencia namespaced e IPC. Superficies:
//   launcher   → MenuDefinition registrados en MenuStore.
//   bar-widget → componentes compilados; MainBar los instancia por pantalla.
//   daemon     → objetos únicos propiedad del servicio.
//   panel      → componentes compilados; PluginPanelHost los muestra.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules
import qs.Launcher

Singleton {
    id: root

    readonly property string shinroVersion: "1.0.0"
    readonly property string pluginsDir: Directories.config + "/shinro/plugins"
    readonly property string statePath: Directories.state + "/shinro/plugins.json"

    // Estado persistido: { enabled: {id: bool}, data: {id: {...}} }.
    // Ausencia en enabled = activado (tu ~/.config = tu confianza).
    property var pluginState: ({ enabled: ({}), data: ({}) })

    // Manifiestos válidos: [{id,name,version,author,type,capabilities,
    // component,zone,order,trigger,settings,requires_shinro,permissions,dir}]
    property var available: []
    // Objetos launcher instanciados (propiedad de este servicio;
    // MenuStore solo los referencia, nunca los destruye) + ids en
    // paralelo (las raíces MenuDefinition/QtObject no admiten props
    // extra: no se les puede estampar el pluginId encima).
    property var launcherObjects: []
    property var launcherIds: []
    // Componentes compilados para instanciación diferida:
    // widgets (uno por pantalla, vía MainBar) y panels (vía host).
    property var widgetComps: ({})
    property var panelComps: ({})
    // Objetos daemon vivos (únicos, propiedad del servicio) + ids.
    property var daemonObjects: []
    property var daemonIds: []
    // trigger -> sectionId (solo launchers cargados; longest-match).
    property var triggerMap: ({})
    readonly property var classicTriggers: [">", "/", "@", ".", "=", ":"]
    // Panel visible en el host ("" = ninguno).
    property string activePanelId: ""
    // pluginId -> dict i18n fusionado en el escaneo (i18n/<lang>.json).
    property var pluginStrings: ({})

    property int revision: 0
    property int loadEpoch: 0
    property int loadErrors: 0
    property string lastError: ""
    // Errores por plugin (visibles vía IPC).
    property var pluginErrors: ({})

    // Excusa para instanciar desde shell.qml (como ConfigService.load()).
    function load() {
    }

    // ---------- estado persistido ----------
    Timer {
        id: stateWriteTimer

        interval: 100
        repeat: false
        onTriggered: stateFile.setText(JSON.stringify(root.pluginState))
    }
    Timer {
        id: stateReloadTimer

        interval: 100
        repeat: false
        onTriggered: stateFile.reload()
    }

    FileView {
        id: stateFile

        path: root.statePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: stateReloadTimer.restart()
        onLoaded: {
            try {
                const s = JSON.parse(stateFile.text());
                if (s && typeof s === "object") {
                    if (!s.enabled || typeof s.enabled !== "object")
                        s.enabled = ({});
                    if (!s.data || typeof s.data !== "object")
                        s.data = ({});
                    root.pluginState = s;
                }
            } catch (e) {
                console.warn("PluginService: estado corrupto, se usa vacío");
                root.pluginState = ({ enabled: ({}), data: ({}) });
            }
        }
        onLoadFailed: error => {
            // Primera ejecución: se crea con defaults al guardar.
            if (error == FileViewError.FileNotFound)
                stateWriteTimer.restart();
            else
                console.warn("PluginService: no se pudo leer estado:", error);
        }
    }

    function saveState() {
        stateWriteTimer.restart();
    }

    function isEnabled(id) {
        const e = (root.pluginState && root.pluginState.enabled) || ({});
        return e[id] === undefined ? true : !!e[id];
    }

    function setEnabled(id, on) {
        const st = JSON.parse(JSON.stringify(root.pluginState));
        if (!st.enabled || typeof st.enabled !== "object")
            st.enabled = ({});
        st.enabled[id] = !!on;
        root.pluginState = st;
        saveState();
        root.rescan();
    }

    // Persistencia namespaced por plugin (análogo a pluginData de DMS).
    function getData(pluginId) {
        const d = (root.pluginState && root.pluginState.data) || ({});
        const v = d[pluginId];
        return v !== undefined ? v : ({});
    }

    function setData(pluginId, obj) {
        const st = JSON.parse(JSON.stringify(root.pluginState));
        if (!st.data || typeof st.data !== "object")
            st.data = ({});
        st.data[pluginId] = (obj !== undefined && obj !== null) ? obj : ({});
        root.pluginState = st;
        saveState();
    }

    // Proveedor vivo de una capability (daemons): p. ej.
    // providerForCapability("video-wallpaper-backend"). Sin proveedor → null.
    // Las capabilities en manifiestos no-daemon son informativas.
    function providerForCapability(cap) {
        for (let i = 0; i < root.daemonObjects.length; i++) {
            const a = root.pluginById(root.daemonIds[i]);
            if (a && (a.capabilities || []).indexOf(cap) >= 0)
                return root.daemonObjects[i];
        }
        return null;
    }

    function daemonObjectById(id) {
        const i = root.daemonIds.indexOf(id);
        return i >= 0 ? root.daemonObjects[i] : null;
    }

    function clearError(id) {
        if (root.pluginErrors[id] === undefined)
            return;
        const errs = Object.assign({}, root.pluginErrors);
        delete errs[id];
        root.pluginErrors = errs;
        root.lastError = "";
    }

    // i18n con scope: dict del plugin -> plugin.<id>.<key> global -> default.
    function tr(pluginId, key, fallback) {
        const d = root.pluginStrings[pluginId];
        if (d) {
            const v = d[key];
            if (v !== undefined && v !== null)
                return v;
        }
        return I18nService.getTranslation("plugin." + pluginId + "." + key, fallback !== undefined ? fallback : "");
    }

    function pluginById(id) {
        for (let i = 0; i < root.available.length; i++)
            if (root.available[i].id === id)
                return root.available[i];
        return null;
    }

    function launcherObjectById(id) {
        const i = root.launcherIds.indexOf(id);
        return i >= 0 ? root.launcherObjects[i] : null;
    }

    // ---------- descubrimiento ----------
    Component.onCompleted: {
        scanProc.command = root.scanCommand();
        scanProc.running = true;
    }

    // Un solo proceso lista dirs + vuelca plugin.json + i18n/<lang>.json
    // del idioma activo. Bloques "@DIR:.. @I18N:.. @END" (ver finishScan).
    function scanCommand() {
        const lang = I18nService.language || "en_US";
        const p = root.pluginsDir.replace(/'/g, "'\\''");
        return ["sh", "-c",
            "for d in '" + p + "'/*/; do [ -d \"$d\" ] || continue; " +
            "[ -f \"$d/plugin.json\" ] || continue; " +
            "echo \"@DIR:$d\"; cat \"$d/plugin.json\"; echo; " +
            "echo \"@I18N:\"; cat \"$d/i18n/" + lang + ".json\" 2>/dev/null; echo; " +
            "echo \"@END\"; done"];
    }

    // Recarga en vivo sin polling: firma stat de manifiestos + código.
    property string dirSignature: ""
    property string watchAcc: ""
    property string scanAcc: ""

    function checkNow() {
        if (!watchProc.running && !scanProc.running)
            watchProc.running = true;
    }

    function rescan() {
        if (scanProc.running)
            return false;
        root.loadEpoch += 1;
        scanProc.command = root.scanCommand();
        scanProc.running = true;
        return true;
    }

    Process {
        id: watchProc

        command: ["sh", "-c",
            "for d in '" + root.pluginsDir.replace(/'/g, "'\\''") + "'/*/; do [ -d \"$d\" ] || continue; " +
            "for f in \"$d\"/plugin.json \"$d\"/*.qml \"$d\"/*.js \"$d\"/i18n/*.json; do [ -f \"$f\" ] || continue; " +
            "stat -c '%n|%Y|%s' \"$f\"; done; done | sort"]
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
                root.rescan();
            }
        }
    }

    Process {
        id: scanProc

        stdout: SplitParser {
            onRead: data => {
                // SplitParser entrega líneas sin separador: se repone
                // (igual que MenuStore.watchAcc) o el parse pierde marcas.
                root.scanAcc += data + "\n";
            }
        }
        onRunningChanged: {
            if (running)
                root.scanAcc = "";
        }
        onExited: code => root.finishScan(code)
    }

    function reservedId(id) {
        return ["main", "todo", "system", "files", "web", "emoji", "calc", "clip",
            "powerprofiles", "fastfetch", "animations", "plugins"].indexOf(id) >= 0;
    }

    function satisfiesRequires(req) {
        if (req === undefined || req === null || req === "" || req === "*")
            return true;
        const m = String(req).match(/^>=\s*(\d+)(?:\.(\d+))?/);
        if (m) {
            const cur = root.shinroVersion.split(".");
            const needMaj = parseInt(m[1], 10), needMin = parseInt(m[2] || "0", 10);
            const curMaj = parseInt(cur[0], 10), curMin = parseInt(cur[1], 10);
            return curMaj > needMaj || (curMaj === needMaj && curMin >= needMin);
        }
        return String(req) === root.shinroVersion;
    }

    function parseScan(text) {
        const found = [];
        const strings = {};
        const blocks = String(text || "").split("@END");
        for (let b = 0; b < blocks.length; b++) {
            const block = blocks[b];
            if (block.indexOf("@DIR:") < 0)
                continue;
            const dirLine = block.slice(block.indexOf("@DIR:") + 5);
            const dir = dirLine.slice(0, dirLine.indexOf("\n")).trim().replace(/\/$/, "");
            const i18nIdx = block.indexOf("@I18N:");
            const manifestText = (i18nIdx >= 0 ? block.slice(block.indexOf("\n", block.indexOf("@DIR:")), i18nIdx) : block).trim();
            const i18nText = i18nIdx >= 0 ? block.slice(i18nIdx + 6).trim() : "";
            let m = null;
            try {
                m = JSON.parse(manifestText);
            } catch (e) {
                root.noteError(dir, "plugin.json inválido: " + e);
                continue;
            }
            const checked = root.validateManifest(dir, m);
            if (!checked.ok) {
                root.noteError(dir, checked.error);
                continue;
            }
            found.push(checked.entry);
            if (i18nText !== "") {
                try {
                    const d = JSON.parse(i18nText);
                    if (d && typeof d === "object")
                        strings[checked.entry.id] = d;
                } catch (e) {
                    // i18n opcional y tolerante: se ignora y cae al fallback.
                }
            }
        }
        return { found: found, strings: strings };
    }

    function validateManifest(dir, m) {
        if (!m || typeof m !== "object")
            return { ok: false, error: "manifiesto vacío" };
        const id = String(m.id || "");
        if (!/^[a-z0-9][a-z0-9_-]*$/.test(id))
            return { ok: false, error: "id inválido '" + m.id + "' (^[a-z0-9][a-z0-9_-]*$)" };
        if (root.reservedId(id))
            return { ok: false, error: "id reservado '" + id + "'" };
        if (["launcher", "bar-widget", "panel", "daemon"].indexOf(m.type) < 0)
            return { ok: false, error: "'" + id + "': type desconocido '" + m.type + "'" };
        const comp = String(m.component || "");
        if (comp === "" || comp.indexOf("..") >= 0)
            return { ok: false, error: "'" + id + "': component inválido" };
        const trigger = (m.trigger !== undefined && m.trigger !== null) ? String(m.trigger) : "";
        if (trigger !== "") {
            if (m.type !== "launcher")
                return { ok: false, error: "'" + id + "': trigger requiere type launcher" };
            if (!/^\S{1,8}$/.test(trigger) || root.classicTriggers.indexOf(trigger) >= 0)
                return { ok: false, error: "'" + id + "': trigger inválido '" + trigger + "' (sin espacios, máx 8, no > / @ . = :)" };
        }
        let order = 100;
        if (m.order !== undefined && m.order !== null) {
            if (typeof m.order !== "number")
                return { ok: false, error: "'" + id + "': order debe ser número" };
            order = m.order;
        }
        const exts = [];
        if (m.extensions !== undefined && m.extensions !== null) {
            if (!Array.isArray(m.extensions))
                return { ok: false, error: "'" + id + "': extensions debe ser array" };
            for (let e = 0; e < m.extensions.length; e++)
                exts.push(String(m.extensions[e]).toLowerCase());
        }
        const zone = String(m.zone || "right");
        if (["left", "center", "right"].indexOf(zone) < 0)
            return { ok: false, error: "'" + id + "': zone inválida '" + m.zone + "'" };
        if (!root.satisfiesRequires(m.requires_shinro))
            return { ok: false, error: "'" + id + "' requiere shinro " + m.requires_shinro + " (actual " + root.shinroVersion + ")" };
        return {
            ok: true,
            entry: {
                id: id, name: String(m.name || id), description: String(m.description || ""),
                version: String(m.version || "0.0.0"), author: String(m.author || ""),
                type: m.type, capabilities: m.capabilities || [],
                component: comp.replace(/^\.\//, ""), zone: zone, order: order,
                trigger: trigger, settings: m.settings || "",
                extensions: exts,
                requires_shinro: m.requires_shinro || "", permissions: m.permissions || [],
                dir: dir
            }
        };
    }

    function noteError(idOrDir, msg) {
        // Reasignación (no mutación) para notificar a los bindings
        // que leen pluginErrors (widgetsForZone, statusOf).
        const errs = Object.assign({}, root.pluginErrors);
        errs[idOrDir] = msg;
        root.pluginErrors = errs;
        root.lastError = msg;
        console.warn("PluginService: " + msg);
    }

    function finishScan(code) {
        if (code !== 0) {
            root.lastError = "escaneo falló (código " + code + ")";
            console.warn("PluginService: " + root.lastError);
            return;
        }
        const r = root.parseScan(root.scanAcc);
        root.available = r.found;
        root.pluginStrings = r.strings;
        root.instantiateLaunchers();
        root.compileSurfaces();
        root.instantiateDaemons();
        // Si el panel abierto dejó de ser válido, se cierra solo.
        if (root.activePanelId !== "" && root.panelEntries().indexOf(root.activePanelId) < 0)
            root.activePanelId = "";
        // Backend de fondos: decide estático o proveedor (idempotente).
        WallpaperService.ensureBackend();
        // Un solo bump por escaneo (lo leen Registry, MainBar y host).
        root.revision += 1;
    }

    function loadOne(entry) {
        // Como MenuStore.loadOne: ?epoch= rompe la caché del motor en reloads.
        const comp = Qt.createComponent(root.componentUrl(entry));
        if (comp.status !== Component.Ready) {
            root.noteError(entry.id, entry.id + ": " + comp.errorString());
            return null;
        }
        const obj = comp.createObject(root, {});
        if (!obj || !obj.sectionId) {
            root.noteError(entry.id, entry.id + " no expone sectionId (¿raíz MenuDefinition?), se ignora");
            if (obj)
                obj.destroy();
            return null;
        }
        // Core y menús de usuario mandan: el plugin nunca los pisa.
        // (Los objetos plugin viejos aún registrados no cuentan como
        // colisión: se reemplazan en este mismo rescan.)
        const clash = MenuStore.providerFor(obj.sectionId);
        const clashIsStalePlugin = clash && root.launcherObjects.indexOf(clash) >= 0;
        if (clash && clash !== obj && !clashIsStalePlugin) {
            root.noteError(entry.id, "sectionId '" + obj.sectionId + "' en colisión, se ignora");
            obj.destroy();
            return null;
        }
        if (root.sectionTakenByPlugin(obj.sectionId, entry.id)) {
            root.noteError(entry.id, "sectionId '" + obj.sectionId + "' duplicado entre plugins, se ignora");
            obj.destroy();
            return null;
        }
        return obj;
    }

    function sectionTakenByPlugin(sectionId, exceptId) {
        for (let i = 0; i < root.launcherObjects.length; i++)
            if (root.launcherObjects[i].sectionId === sectionId && root.launcherIds[i] !== exceptId)
                return true;
        return false;
    }

    function instantiateLaunchers() {
        const fresh = [];
        const freshIds = [];
        const seenIds = {};
        const seenSections = {};
        let errors = 0;
        for (let i = 0; i < root.available.length; i++) {
            const a = root.available[i];
            if (a.type !== "launcher" || !root.isEnabled(a.id))
                continue;
            if (seenIds[a.id]) {
                root.noteError(a.id, "plugin duplicado '" + a.id + "', se ignora");
                errors += 1;
                continue;
            }
            seenIds[a.id] = true;
            const obj = root.loadOne(a);
            if (!obj) {
                errors += 1;
                continue;
            }
            if (seenSections[obj.sectionId]) {
                root.noteError(a.id, "sectionId '" + obj.sectionId + "' duplicado entre plugins, se ignora");
                obj.destroy();
                errors += 1;
                continue;
            }
            seenSections[obj.sectionId] = true;
            fresh.push(obj);
            freshIds.push(a.id);
        }
        // Todo-o-nada como MenuStore: con errores y habiendo previos,
        // se conservan los viejos (mejor menú viejo que roto).
        root.loadErrors = errors;
        if (errors > 0 && root.loadEpoch > 0 && root.launcherObjects.length > 0) {
            console.warn("PluginService: " + errors + " plugin(s) con error, se conservan los actuales");
            for (let d = 0; d < fresh.length; d++)
                fresh[d].destroy();
            return;
        }
        const old = root.launcherObjects;
        root.launcherObjects = fresh;
        root.launcherIds = freshIds;
        // Mapa trigger -> sectionId (longest-match en triggerFor).
        // Trigger duplicado: se cae el trigger, no el menú.
        const tmap = {};
        for (let t = 0; t < fresh.length; t++) {
            const pe = root.pluginById(freshIds[t]);
            const tg = pe ? pe.trigger : "";
            if (tg === "")
                continue;
            if (tmap[tg] !== undefined)
                root.noteError(freshIds[t], "trigger '" + tg + "' duplicado, se ignora el trigger");
            else
                tmap[tg] = fresh[t].sectionId;
        }
        root.triggerMap = tmap;
        // Se publica antes de destruir (la UI nunca queda vacía).
        MenuStore.setPluginProviders(fresh);
        for (let k = 0; k < old.length; k++)
            old[k].destroy();
        if (errors === 0)
            root.lastError = "";
        // Los dinámicos regeneran entries con la nueva instancia.
        for (let r = 0; r < fresh.length; r++)
            if (typeof fresh[r].refresh === "function")
                fresh[r].refresh();
    }

    // trigger -> {trigger, section} (longest-match) o null.
    // Lee triggerMap: reactivo a rescans.
    function triggerFor(text) {
        const t = String(text || "");
        if (t === "")
            return null;
        const map = root.triggerMap;
        let best = null;
        for (const k in map)
            if (t.startsWith(k) && (!best || k.length > best.trigger.length))
                best = { trigger: k, section: map[k] };
        return best;
    }

    // Contexto inyectable: {id, version, dir}. Si la raíz declara
    // `property var plugin`, el instanciador se lo asigna; si no,
    // el componente usa la API singleton directamente.
    function pluginContext(pluginId) {
        const a = root.pluginById(pluginId);
        return { id: pluginId, version: a ? a.version : "", dir: a ? a.dir : "" };
    }

    // Asignación tolerante: true si la raíz aceptó el contexto.
    function injectContext(item, pluginId) {
        if (!item)
            return false;
        try {
            item.plugin = root.pluginContext(pluginId);
            return true;
        } catch (e) {
            return false;
        }
    }

    function componentUrl(entry) {
        return "file://" + entry.dir + "/" + entry.component + (root.loadEpoch > 0 ? "?epoch=" + root.loadEpoch : "");
    }

    // Compila widgets y panels habilitados (la instanciación la hacen
    // MainBar por pantalla y el host de panel). Errores → pluginErrors.
    function compileSurfaces() {
        const wcomps = {};
        const pcomps = {};
        for (let i = 0; i < root.available.length; i++) {
            const a = root.available[i];
            if ((a.type !== "bar-widget" && a.type !== "panel") || !root.isEnabled(a.id))
                continue;
            if (root.pluginErrors[a.id])
                continue;
            const comp = Qt.createComponent(root.componentUrl(a));
            if (comp.status !== Component.Ready) {
                root.noteError(a.id, a.id + ": " + comp.errorString());
                continue;
            }
            if (a.type === "bar-widget")
                wcomps[a.id] = comp;
            else
                pcomps[a.id] = comp;
        }
        root.widgetComps = wcomps;
        root.panelComps = pcomps;
    }

    // [{id, component}] ordenados por (order, id) para una zona.
    function widgetsForZone(zone) {
        root.revision;
        const comps = root.widgetComps;
        const errs = root.pluginErrors;
        const out = [];
        for (let i = 0; i < root.available.length; i++) {
            const a = root.available[i];
            if (a.type !== "bar-widget" || a.zone !== zone || !root.isEnabled(a.id))
                continue;
            if (!comps[a.id] || errs[a.id])
                continue;
            out.push({ id: a.id, order: a.order, component: comps[a.id] });
        }
        out.sort((x, y) => (x.order !== y.order) ? x.order - y.order : (x.id < y.id ? -1 : 1));
        return out;
    }

    function panelComponent(pluginId) {
        return root.panelComps[pluginId] || null;
    }

    function panelEntries() {
        root.revision;
        const comps = root.panelComps;
        const errs = root.pluginErrors;
        const out = [];
        for (let i = 0; i < root.available.length; i++) {
            const a = root.available[i];
            if (a.type !== "panel" || !root.isEnabled(a.id))
                continue;
            if (!comps[a.id] || errs[a.id])
                continue;
            out.push(a.id);
        }
        return out;
    }

    function openPanel(pluginId) {
        if (root.panelEntries().indexOf(pluginId) < 0)
            return "unknown/inactive panel '" + pluginId + "'";
        root.activePanelId = pluginId;
        return "ok panel '" + pluginId + "' open";
    }

    function closePanel() {
        root.activePanelId = "";
    }

    // Daemons: objetos únicos vivos hasta el próximo rescan.
    function instantiateDaemons() {
        for (let k = 0; k < root.daemonObjects.length; k++)
            root.daemonObjects[k].destroy();
        const objs = [];
        const ids = [];
        for (let i = 0; i < root.available.length; i++) {
            const a = root.available[i];
            if (a.type !== "daemon" || !root.isEnabled(a.id))
                continue;
            if (root.pluginErrors[a.id])
                continue;
            const comp = Qt.createComponent(root.componentUrl(a));
            if (comp.status !== Component.Ready) {
                root.noteError(a.id, a.id + ": " + comp.errorString());
                continue;
            }
            let obj = null;
            try {
                obj = comp.createObject(root, { plugin: root.pluginContext(a.id) });
            } catch (e1) {
                try {
                    obj = comp.createObject(root, {});
                } catch (e2) {
                    obj = null;
                }
            }
            if (!obj) {
                root.noteError(a.id, a.id + ": no se pudo instanciar el daemon");
                continue;
            }
            objs.push(obj);
            ids.push(a.id);
        }
        root.daemonObjects = objs;
        root.daemonIds = ids;
    }

    // Re-filtra sin recrear cuando MenuStore recarga después que nosotros
    // (carrera de arranque): si core/usuario pisa una sección plugin,
    // se excluye. Con guarda anti-bucle (ver setPluginProviders).
    Connections {
        target: MenuStore
        function onRevisionChanged() {
            root.refilterLaunchers();
        }
    }

    function refilterLaunchers() {
        const valid = [];
        for (let i = 0; i < root.launcherObjects.length; i++) {
            const o = root.launcherObjects[i];
            const holder = MenuStore.providerFor(o.sectionId);
            // null = MenuStore aún sin providers (válido); o mismo objeto
            // (ya registrado); otro objeto = core/usuario manda, se excluye.
            if (!holder || holder === o)
                valid.push(o);
            else
                console.warn("PluginService: sección '" + o.sectionId + "' sombreada por core/usuario, se excluye");
        }
        MenuStore.setPluginProviders(valid);
    }

    // ---------- IPC: qs ipc call plugins <list|rescan|enable|disable|reload|open-panel|close-panel> ----------
    // OJO: dentro de IpcHandler solo van las funciones expuestas (firmas
    // IPC); los helpers viven fuera o el motor protesta (QVariant en IPC).
    function statusOf(a) {
        if (!root.isEnabled(a.id))
            return "disabled";
        const err = root.pluginErrors[a.id];
        const suffix = err ? " [warn: " + err + "]" : "";
        if (a.type === "launcher")
            return (root.launcherObjectById(a.id) ? "loaded" : "pending") + suffix;
        if (a.type === "bar-widget")
            return (root.widgetComps[a.id] ? "active" : "pending") + suffix;
        if (a.type === "daemon")
            return (root.daemonIds.indexOf(a.id) >= 0 ? "running" : "pending") + suffix;
        return (root.panelComps[a.id] ? "available" : "pending") + suffix;
    }

    IpcHandler {
        target: "plugins"

        function list(): string {
            const out = [];
            for (let i = 0; i < root.available.length; i++) {
                const a = root.available[i];
                out.push({ id: a.id, name: a.name, version: a.version, type: a.type, enabled: root.isEnabled(a.id), status: root.statusOf(a) });
            }
            return JSON.stringify({ plugins: out, revision: root.revision, errors: root.loadErrors, lastError: root.lastError });
        }

        function rescan(): string {
            const started = root.rescan();
            return (started ? "rescanning" : "already-scanning") + " rev=" + root.revision + " errors=" + root.loadErrors;
        }

        function enable(id: string): string {
            if (!root.pluginById(id))
                return "unknown plugin '" + id + "'";
            root.setEnabled(id, true);
            return "ok '" + id + "' enabled (rescanning)";
        }

        function disable(id: string): string {
            if (!root.pluginById(id))
                return "unknown plugin '" + id + "'";
            root.setEnabled(id, false);
            return "ok '" + id + "' disabled (rescanning)";
        }

        function reload(id: string): string {
            // v1: la recarga es global (barata: stat + rescan).
            if (id && !root.pluginById(id))
                return "unknown plugin '" + id + "'";
            const started = root.rescan();
            return (started ? "rescanning" : "already-scanning") + (id ? " id=" + id : "") + " rev=" + root.revision;
        }

        function openPanel(id: string): string {
            return root.openPanel(id || "");
        }

        function closePanel(): string {
            root.closePanel();
            return "ok panel closed";
        }
    }
}
