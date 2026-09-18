// --- UnifiedLauncher (antes AppLauncher) ---
// Menú único con FuzzySearch en todo:
//   modos por prefijo:
//     (nada) todo: apps + calc + sistema + atajo web
//     >  sistema (menús personalizados: secciones CustomMenu de
//        MenuProviders/System/ + MenuProviders/*.qml, estáticos o
//        dinámicos vía refresh())
//     /  archivos (fd en $HOME)
//     @  búsqueda web (DuckDuckGo)
//     .  emojis/símbolos (EmojiService: catálogo + librería python,
//        grupos, recientes/favoritos; Enter copia -> wl-copy)
//     =  calculadora
//     :  portapapeles (cliphist, texto + preview de imágenes)
// Panel derecho = preview (iconos grandes, imágenes de archivos,
// capturas del clipboard, wallpapers).
pragma ComponentBehavior: Bound
import qs.Core
import qs.Core.Modules
import qs.Core.Services as Services
import qs.Primitives
import qs.Shared.Background
import "MenuModes.js" as MenuModes
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: launcher

    property bool launcherVisible: false
    // Modo forzado por IPC ("" = según prefijo del texto)
    property string forcedMode: ""
    // Sección actual del menú de sistema (navegación estilo Omarchy)
    property string menuSection: "main"

    visible: launcherVisible

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.launcherVisible = false
    }

    HyprlandFocusGrab {
        windows: [launcher]
        active: launcher.launcherVisible
        onCleared: Qt.callLater(() => launcher.launcherVisible = false)
    }

    WlrLayershell.keyboardFocus: launcher.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.layer: WlrLayer.Overlay

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.forcedMode = "";
            launcher.launcherVisible = !launcher.launcherVisible;
        }
        function openClipboard(): void {
            toggleMode("clip");
        }
        function openEmoji(): void {
            toggleMode("emoji");
        }
        function openSystem(): void {
            launcher.menuSection = "main";
            toggleMode("system");
        }
        function openMenu(section: string): void {
            const target = section || "main";
            if (launcher.launcherVisible && launcher.activeMode === "system" && launcher.menuSection === target) {
                launcher.launcherVisible = false;
                return;
            }
            launcher.forcedMode = "system";
            launcher.launcherVisible = true;
            // Igual que navegar con chips o teclear ">": el campo muestra el
            // carácter y la sección se refresca (al abrir ya lo pone
            // onLauncherVisibleChanged; si seguía abierto hay que ponerlo aquí).
            launcher.goSection(target);
        }
        // Recarga los menús personalizados sin recargar todo el shell:
        // `qs ipc call launcher reloadMenus` -> "menus=S+U rev=N [...]".
        // Re-escanea MenuProviders/, recrea los providers (con la última
        // versión de cada fichero) y refresca los dinámicos. La UI se
        // actualiza sola vía CustomMenuService.revision.
        function reloadMenus(): string {
            return SystemMenuRegistry.reloadCustomMenus();
        }
        // Toggle por menú: si ya está abierto en ese menú, cierra; si no, abre.
        // Al cambiar, el campo muestra el carácter del modo, igual que al
        // pulsar su chip o teclear su prefijo (uniforme en las tres vías).
        function toggleMode(name: string): void {
            const m = name || "todo";
            const cur = launcher.forcedMode !== "" ? launcher.forcedMode : launcher.activeMode;
            if (launcher.launcherVisible && cur === m) {
                launcher.launcherVisible = false;
                return;
            }
            if (m === "system") {
                launcher.forcedMode = "system";
                launcher.launcherVisible = true;
                launcher.goSection("main");
                return;
            }
            launcher.forcedMode = (m === "todo") ? "" : m;
            launcher.launcherVisible = true;
            // Al abrir ya lo pone onLauncherVisibleChanged; si seguía
            // abierto hay que ponerlo aquí (si no, el prefijo viejo
            // seguiría mandando sobre el modo forzado).
            searchField.text = launcher.prefixOf(launcher.forcedMode);
            searchField.forceActiveFocus();
        }
    }

    // ---------- menús: distintos, misma base (ver MenuModes.js) ----------
    // Cada menú tiene su carácter selector (pfx). Teclearlo cambia de menú.
    readonly property var modes: MenuModes.defs()

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    function modeLabel(id) {
        switch (id) {
        case "todo": return tr("launcher.tab_todo", "Todo");
        case "system": return tr("launcher.tab_system", "Sistema");
        case "files": return tr("launcher.tab_files", "Archivos");
        case "web": return tr("launcher.tab_web", "Web");
        case "emoji": return tr("launcher.tab_emoji", "Emojis");
        case "calc": return tr("launcher.tab_calc", "Calc");
        default: return tr("launcher.tab_clip", "Clipboard");
        }
    }

    // Warmup: este binding se evalúa al arrancar el shell y dispara el
    // escaneo asíncrono de .desktop (si no, la primera apertura tardaba
    // segundos en listar). Estado de carga para mostrar "Cargando…".
    // Número de apps instaladas. Se actualiza solo cuando Quickshell
    // detecta cambios en los .desktop. Solo se usa para el texto
    // "Cargando…" cuando aún no hay ninguna.
    property int appCount: DesktopEntries.applications.values.length

    function prefixOf(modeId) {
        return MenuModes.prefixOf(modeId);
    }

    // Prefijo tecleado (tiene prioridad: los caracteres siempre cambian de menú)
    function typedMode() {
        return MenuModes.modeForPrefix(searchField.text);
    }

    // Modo activo: prefijo tecleado manda; si no, modo forzado por IPC.
    property string activeMode: {
        const typed = typedMode();
        if (typed !== "")
            return typed;
        if (forcedMode !== "")
            return forcedMode;
        return "todo";
    }

    // Query sin prefijo
    property string query: {
        const t = searchField.text;
        const m = launcher.activeMode;
        if (m !== "todo") {
            const p = launcher.prefixOf(m);
            if (p !== "" && t.startsWith(p))
                return t.slice(p.length).trim();
        }
        return t.trim();
    }

    onLauncherVisibleChanged: {
        if (launcherVisible) {
            menuSection = forcedMode === "system" ? menuSection : "main";
            searchField.text = launcher.prefixOf(forcedMode);
            fileResults.clear();
            fileSnapshot = [];
            previewOk = false;
            // Cada apertura empieza en orden canónico (no congelado).
            launcher.frozenIds = [];
            // La selección vuelve al principio en cada apertura.
            resultList.currentIndex = 0;
            resultList.positionViewAtBeginning();
            if (forcedMode === "clip" || forcedMode === "")
                Services.ClipboardService.refresh();
            // Modelos live del menú de sistema (búsqueda global + badges "Actual",
            // más menús propios; no-op si aún no se descubrieron).
            SystemMenuRegistry.refreshAll();
            searchField.forceActiveFocus();
        } else {
            forcedMode = "";
            // Sin selecciones a medias al cerrar: el diferido no debe pintar
            // nada de una sesión ya cerrada.
            previewDebounce.stop();
            previewPendingIndex = -1;
        }
    }

    // Entrar a una sección (click, breadcrumb, IPC): refresca si es dinámica
    // (interna o propia; no-op en el resto).
    function goSection(id) {
        menuSection = id;
        searchField.text = ">";
        SystemMenuRegistry.refreshSection(id);
        searchField.forceActiveFocus();
    }

    // Mueve la selección con cycle: del último vuelve al primero y viceversa.
    // Al dar la vuelta se avisa discreto: línea fina en el borde hacia
    // donde se saltó (arriba = al primero, abajo = al último).
    property bool wrapFlash: false
    property int wrapDir: 0

    Timer {
        id: wrapTimer

        interval: 220
        onTriggered: launcher.wrapFlash = false
    }

    function moveSelection(delta) {
        const n = resultList.count;
        if (n === 0)
            return;
        let i = resultList.currentIndex + delta;
        if (i < 0 || i >= n) {
            launcher.wrapDir = i < 0 ? -1 : 1;
            launcher.wrapFlash = true;
            wrapTimer.restart();
        }
        if (i < 0)
            i = n - 1;
        else if (i >= n)
            i = 0;
        resultList.currentIndex = i;
        resultList.positionViewAtIndex(i, ListView.Contain);
    }

    // Al entrar a modo clipboard refresca historial
    onActiveModeChanged: {
        if (launcherVisible && activeMode === "clip")
            Services.ClipboardService.refresh();
        if (activeMode === "files")
            fileDebounce.restart();
        if (launcherVisible && activeMode === "calc")
            calcDebounce.restart();
    }

    // ---------- helpers ----------
    // Sin shellEscape local: la copia de texto va por
    // ClipboardService.copyText (misma semántica, vía única).

    // Lanzamiento desacoplado: los comandos abren GUIs de larga vida
    // (emacsclient, terminales, wlogout, hyprpicker…). Un Process atado al
    // shell seguiría en `running` mientras la app siga abierta y el
    // siguiente lanzamiento se ignoraría en silencio; execDetached no
    // bloquea ni mata el wl-copy anterior al reutilizarse.
    function runCmd(cmd) {
        Quickshell.execDetached(cmd);
    }
    function runShell(shell) {
        Quickshell.execDetached(["sh", "-c", shell]);
    }

    function activateCurrent() {
        const item = resultList.currentItem;
        if (!item || !item.modelData)
            return;
        activateItem(item.modelData);
    }

    function activateItem(it) {
        // Entrada cruda de DesktopEntries (modo todo con appModel):
        // no trae `kind`, se detecta por el método execute().
        if (it && typeof it.execute === "function") {
            if (it.runInTerminal)
                Quickshell.execDetached({
                    command: ["xdg-terminal-exec", "-e"].concat(it.command),
                    workingDirectory: it.workingDirectory
                });
            else
                it.execute();
            launcher.launcherVisible = false;
            return;
        }
        // Navegación entre secciones: no cierra el menú.
        if (it.kind === "menuback" || (it.kind === "system" && it.isSubmenu)) {
            launcher.goSection(it.section);
            return;
        }
        switch (it.kind) {
        case "system":
            launcher.runShell(it.shell);
            break;
        case "emoji":
            EmojiService.copy(it.ch);
            break;
        case "clip":
            Services.ClipboardService.copyEntry(it.cid, it.isImage);
            break;
        case "file":
            launcher.runCmd(["xdg-open", it.path]);
            break;
        case "calc":
            Services.ClipboardService.copyText(it.result);
            break;
        case "web":
            launcher.runCmd(["xdg-open", it.url]);
            break;
        }
        launcher.launcherVisible = false;
    }

    // ---------- calculadora vía libqalculate (qalc) ----------
    // El cálculo lo hace qalc (-t = salida escueta); aquí solo se decide
    // cuándo pedirlo y se muestra el resultado. Sin shell: argv directo.
    property string calcResult: ""
    property string calcForQuery: ""
    property bool calcBusy: false

    // ¿Parece cálculo? Debe llevar dígito y solo caracteres plausibles
    // (números, operadores, unidades, funciones, monedas). El modo calc es
    // explícito (=), así que lo raro lo interpreta qalc como sabe.
    function looksLikeCalc(q) {
        const t = q.trim();
        if (t === "" || !/[0-9]/.test(t))
            return false;
        return /^[\w\s+\-*/%^().,!°√π€$£¥×÷−·'":;<>|&=²³?¡¿-]+$/.test(t);
    }

    Timer {
        id: calcDebounce
        interval: 250
        onTriggered: {
            if (launcher.activeMode !== "calc" || !launcher.launcherVisible)
                return;
            const q = launcher.query;
            if (!launcher.looksLikeCalc(q)) {
                launcher.calcResult = "";
                launcher.calcForQuery = q;
                return;
            }
            // Coma decimal → punto + locale C: igual que antes, punto decimal.
            const expr = q.trim().replace(/,/g, ".");
            launcher.calcBusy = true;
            calcAcc = "";
            calcProc.command = ["env", "LC_ALL=C", "qalc", "-t", expr];
            calcProc.running = true;
        }
    }

    property string calcAcc: ""

    Process {
        id: calcProc
        stdout: SplitParser {
            onRead: data => {
                calcAcc += data + "\n";
            }
        }
        onExited: code => {
            launcher.calcBusy = false;
            const r = calcAcc.trim();
            launcher.calcResult = code === 0 ? r : "";
            launcher.calcForQuery = launcher.query;
        }
    }

    function isUrl(q) {
        if (/\s/.test(q))
            return false;
        return q.startsWith("http://") || q.startsWith("https://") || (/^[a-z0-9-]+(\.[a-z0-9-]+)+/.test(q) && q.indexOf(" ") < 0);
    }

    // ---------- resultados ----------
    property ListModel fileResults: ListModel {}
    // Snapshot de archivos: fileResults se llena por streaming (fd) y leer
    // el ListModel en vivo desde `results` disparaba binding loops.
    property var fileSnapshot: []

    property var results: {
        // lang: reevaluar al cambiar el idioma (los items llevan textos traducidos)
        const lang = Services.I18nService.language;
        const q = launcher.query;
        const m = launcher.activeMode;
        if (m === "system")
            return systemResults(q);
        if (m === "emoji")
            return emojiResults(q);
        if (m === "clip")
            return clipResults(q);
        if (m === "files")
            return fileResultsList(q);
        if (m === "calc")
            return calcResults(q);
        if (m === "web")
            return webResults(q);
        // Modo todo: el ListView usa appModel (ScriptModel) directamente,
        // esta rama queda como fallback vacío.
        return [];
    }

    // ---------- aplicaciones fijadas (modo todo) ----------
    // IDs persistidos en persistence.json. Se leen en appModel para que
    // el modelo se reordene solo al fijar/quitar.
    function pinnedIds() {
        if (!Persistent.ready)
            return [];
        // Ojo: list<string> llega como objeto array-like (isArray false),
        // no como Array JS: se copia a mano en vez de filtrar directo.
        const v = Persistent.persistence.pinnedApps;
        const out = [];
        if (v && typeof v.length === "number") {
            for (let i = 0; i < v.length; i++)
                if (typeof v[i] === "string" && v[i] !== "")
                    out.push(v[i]);
        }
        return out;
    }

    function isPinned(entryId) {
        return launcher.pinnedIds().indexOf(entryId) >= 0;
    }

    function togglePinCurrent() {
        if (launcher.activeMode !== "todo" || !Persistent.ready)
            return;
        const cur = resultList.currentItem;
        const d = cur ? cur.modelData : null;
        if (!d || typeof d.execute !== "function" || !d.id)
            return;
        const pins = launcher.pinnedIds().slice();
        const i = pins.indexOf(d.id);
        if (i >= 0) {
            pins.splice(i, 1);
            // Congela el orden visible actual para no saltar.
            launcher.frozenIds = appModel.values.map(e => e.id);
        } else {
            pins.push(d.id);
            launcher.frozenIds = [];
        }
        Persistent.persistence.pinnedApps = pins;
    }

    function alphaSort(list) {
        return [...list].sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
    }

    // Filtrado estricto por niveles para mostrar lo mínimo:
    // 1º nombre que empieza por la query, si no hay 2º nombre que la
    // contiene, si no hay 3º fuzzy en nombre/comentario/id (tope 15).
    function todoFilter(q, apps) {
        const ql = q.toLowerCase();
        const starts = [];
        const contains = [];
        for (let i = 0; i < apps.length; i++) {
            const n = String(apps[i].name || "").toLowerCase();
            if (n.startsWith(ql))
                starts.push(apps[i]);
            else if (n.indexOf(ql) >= 0)
                contains.push(apps[i]);
        }
        if (starts.length > 0)
            return launcher.alphaSort(starts);
        if (contains.length > 0)
            return launcher.alphaSort(contains);
        return Services.FuzzySearch.filterItemsMulti(q, apps, e => [e.name, e.comment || "", e.id || ""]).slice(0, 15);
    }

    function pinFirst(pool, pins) {
        if (pins.length === 0)
            return pool;
        const byId = {};
        for (let i = 0; i < pool.length; i++)
            byId[pool[i].id] = pool[i];
        const head = [];
        for (let k = 0; k < pins.length; k++)
            if (byId[pins[k]])
                head.push(byId[pins[k]]);
        const tail = [];
        for (let j = 0; j < pool.length; j++)
            if (pins.indexOf(pool[j].id) < 0)
                tail.push(pool[j]);
        // Fijadas también en alfabético: la lista siempre empieza ordenada.
        return launcher.alphaSort(head).concat(tail);
    }

    // Orden visual congelado al desfijar: la app se queda donde está y
    // la lista no salta hasta que se haga una búsqueda, se cambie de
    // modo, se reabra o se fije otra. Guarda IDs en orden visible.
    property var frozenIds: []

    // Deduplica .desktop duplicados (ej. "Aplicaciones web" sale dos veces:
    // webapp-manager.desktop y kde4/webapp-manager.desktop, mismo Exec y
    // mismo nombre). Quickshell filtra Hidden/NoDisplay pero no
    // OnlyShowIn/NotShowIn, así que ambas variantes llegan aquí.
    // Clave = línea de comando normalizada (+ nombre como desempate);
    // ante choque gana la canónica (id sin "kde4", más corto).
    function appDedupKey(e) {
        let cmd = "";
        if (e && e.command && typeof e.command.length === "number" && e.command.length > 0) {
            const parts = [];
            for (let i = 0; i < e.command.length; i++)
                parts.push(String(e.command[i]));
            cmd = parts.join(" ").trim().toLowerCase();
        } else if (e && e.execString) {
            cmd = String(e.execString).trim().toLowerCase();
        }
        const nm = String((e && e.name) || "").trim().toLowerCase();
        if (cmd !== "")
            return "c:" + cmd + "|n:" + nm;
        return "n:" + nm + "|id:" + String((e && e.id) || "");
    }

    function preferApp(a, b) {
        // true = quedarse con b en vez de a.
        const aid = String(a.id || "");
        const bid = String(b.id || "");
        const aKde = aid.toLowerCase().indexOf("kde4") >= 0;
        const bKde = bid.toLowerCase().indexOf("kde4") >= 0;
        if (aKde !== bKde)
            return bKde === false;
        if (bid.length !== aid.length)
            return bid.length < aid.length;
        return false;
    }

    function uniqueApps(list) {
        const seen = {};
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            if (!e || e.noDisplay === true)
                continue;
            const k = launcher.appDedupKey(e);
            if (seen[k] === undefined) {
                seen[k] = out.length;
                out.push(e);
            } else if (launcher.preferApp(out[seen[k]], e)) {
                out[seen[k]] = e;
            }
        }
        return out;
    }

    // ---------- aplicaciones (modo todo) ----------
    // Fuente única y viva: DesktopEntries -> fijadas primero -> filtro.
    // ScriptModel re-suscribe el binding ante altas/bajas de .desktop y
    // actualiza solo los delegates que cambian, sin snapshots ni contadores.
    // Los valores son los DesktopEntry tal cual (identidad estable y
    // única, requisito del ScriptModel); el delegate los pinta directo.
    ScriptModel {
        id: appModel

        values: {
            const base = launcher.uniqueApps([...DesktopEntries.applications.values]);
            const pins = launcher.pinnedIds();
            const q = launcher.query;
            if (q === "" && launcher.frozenIds.length > 0) {
                // Orden congelado al desfijar: reordena con datos vivos
                // (si se desinstaló algo, desaparece) y añade al final en
                // alfabético lo que sea nuevo desde la congelación.
                const live = {};
                for (let b = 0; b < base.length; b++)
                    live[base[b].id] = base[b];
                const frozen = launcher.frozenIds;
                const out = [];
                for (let f = 0; f < frozen.length; f++)
                    if (live[frozen[f]])
                        out.push(live[frozen[f]]);
                const fresh = [];
                for (let n = 0; n < base.length; n++)
                    if (frozen.indexOf(base[n].id) < 0)
                        fresh.push(base[n]);
                return out.concat(launcher.alphaSort(fresh));
            }
            const pool = q === "" ? launcher.alphaSort(base) : launcher.todoFilter(q, base);
            return launcher.pinFirst(pool, pins);
        }
    }

    // Contenido de una sección para navegar (vía única del Registry: internas
    // y propias, estáticas y dinámicas; sin prefijo cat porque el breadcrumb
    // ya indica la sección).
    function sectionItems(id) {
        const info = SystemMenuRegistry.sectionInfo(id);
        const out = [];
        if (info.parentId !== "") {
            const parent = SystemMenuRegistry.sectionInfo(info.parentId);
            out.push({
                kind: "menuback", title: tr("launcher.back_pre", "Atrás · ") + parent.title,
                sub: tr("launcher.back_sub", "Volver a la sección anterior"), iconName: "arrow_back",
                appIcon: "", ch: "", imagePath: "", cat: "",
                shell: "", isSubmenu: false, section: info.parentId
            });
        }
        return out.concat(SystemMenuRegistry.sectionResultItems(id));
    }

    // Todo lo buscable del menú de sistema (vía única del Registry).
    function systemPool() {
        return SystemMenuRegistry.systemSearchPool();
    }

    function systemResults(q) {
        // Sin query → navegación por secciones estilo Omarchy.
        if (q === "")
            return sectionItems(launcher.menuSection);
        return Services.FuzzySearch.filterItemsMulti(q, systemPool(), it => [it.title, it.sub, it.cat]);
    }

    // ---------- emojis vía EmojiService ----------
    // Búsqueda, ranking, grupos, recientes/favoritos y copia centralizada
    // viven en Launcher/EmojiService.qml (catálogo runtime generado por
    // scripts/emoji-dump.py). Aquí solo se delega y se exponen los grupos
    // para los chips de categoría.
    // `revision` como dependencia reactiva: la lista se reevalúa sola
    // al fusionarse la librería o cambiar recientes/favoritos.
    property var emojiGroups: {
        EmojiService.revision;
        EmojiService.ready;
        return EmojiService.groups();
    }

    function emojiResults(q) {
        const rev = EmojiService.revision;
        void rev;
        const cat = tr("launcher.cat_emoji", "Emoji");
        // Sin tope: el buscador permite todos los emojis.
        return EmojiService.queryItems(q, cat);
    }

    // Grupo activo según el token `g:` / `group:` del query actual
    // (normalizado: `g:símbolos` y `g:tech` valen como sus grupos nuevos).
    function emojiActiveGroup() {
        const m = launcher.query.toLowerCase().match(/(?:group|g):([a-záéíóú]+)/);
        return m ? EmojiService.normGroup(m[1]) : "";
    }

    // Chips de categoría: alternan el filtro `g:<id>` manteniendo el resto
    // del query. Equivale a teclear `. g:smileys ...` a mano.
    function toggleEmojiGroup(id) {
        const full = searchField.text;
        const body = full.startsWith(".") ? full.slice(1) : full;
        const m = body.toLowerCase().match(/(?:group|g):([a-záéíóú]+)/);
        let rest = body.replace(/(?:group|g):[a-záéíóú]+/gi, "").trim();
        if (m && EmojiService.normGroup(m[1]) === id)
            searchField.text = rest === "" ? "." : ". " + rest;
        else
            searchField.text = ". g:" + id + (rest !== "" ? " " + rest : "");
        searchField.forceActiveFocus();
    }

    // Favorito sobre la selección (solo modo emoji).
    function toggleFavCurrent() {
        if (launcher.activeMode !== "emoji")
            return;
        const cur = resultList.currentItem;
        const d = cur ? cur.modelData : null;
        if (d && d.ch)
            EmojiService.toggleFavorite(d.ch);
    }

    function clipResults(q) {
        const cat = tr("launcher.cat_clip", "Portapapeles");
        const out = [];
        const snap = Services.ClipboardService.snapshot;
        for (let i = 0; i < snap.length; i++) {
            const e = snap[i];
            out.push({ kind: "clip", title: e.text.length > 90 ? e.text.slice(0, 90) + "…" : e.text,
                       sub: e.isImage ? tr("launcher.clip_image_s", "Imagen · Enter copia · preview →") : tr("launcher.clip_text_s", "Texto · Enter copia · Supr borra"),
                       iconName: e.isImage ? "image" : "content_paste", appIcon: "", ch: "",
                       imagePath: "", cat: cat, cid: e.cid, isImage: e.isImage, fullText: e.text });
        }
        if (q === "")
            return out;
        return Services.FuzzySearch.filterItems(q, out, it => it.title);
    }

    function fileMedia(path, isDir) {
        if (isDir)
            return "other";
        if (/\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(path))
            return "image";
        if (/\.(mp3|flac|m4a|aac|ogg|opus|wav|wma|aiff|ape)$/i.test(path))
            return "audio";
        if (/\.(mp4|m4v|mkv|webm|mov|avi|3gp|ts|mts|flv)$/i.test(path))
            return "video";
        if (/\.pdf$/i.test(path))
            return "pdf";
        if (/\.(txt|md|markdown|json|jsonc|qml|js|ts|py|sh|lua|rs|toml|yaml|yml|ini|conf|cfg|log|csv|css|html|xml|vim|fish|c|h|cpp|hpp|go|java|nix|rasi|desktop)$/i.test(path))
            return "text";
        return "other";
    }

    function fileResultsList(q) {
        const cat = tr("launcher.cat_file", "Archivo");
        const out = [];
        for (let i = 0; i < fileSnapshot.length; i++) {
            const e = fileSnapshot[i];
            const media = fileMedia(e.path, e.isDir);
            let icon = "description";
            if (media === "image")
                icon = "image";
            else if (media === "audio")
                icon = "audio_file";
            else if (media === "video")
                icon = "video_file";
            else if (media === "pdf")
                icon = "picture_as_pdf";
            else if (media === "text")
                icon = "article";
            else if (e.isDir)
                icon = "folder";
            out.push({ kind: "file", title: e.name, sub: e.path,
                       iconName: icon,
                       appIcon: "", ch: "", imagePath: media === "image" ? ("file://" + e.path) : "",
                       cat: cat, path: e.path, media: media });
        }
        if (q === "")
            return out;
        const matches = Services.FuzzySearch.filterItemsMulti(q, out, it => [it.title, it.sub]);
        // El nombre manda: lo que empieza por lo tecleado va primero y el
        // resto mantiene su orden difuso.
        const queryLower = q.toLowerCase();
        const nameFirst = [];
        const nameRest = [];
        for (let i = 0; i < matches.length; i++) {
            const itemTitle = (matches[i].title || "").toLowerCase();
            if (itemTitle.indexOf(queryLower) === 0)
                nameFirst.push(matches[i]);
            else
                nameRest.push(matches[i]);
        }
        return nameFirst.concat(nameRest);
    }

    function calcResults(q) {
        const cat = tr("launcher.cat_calc", "Calc");
        // Solo vale el resultado pedido para este query (si tecleas rápido,
        // el anterior en vuelo se ignora al mostrar).
        const fresh = launcher.calcForQuery === q ? launcher.calcResult : "";
        if (fresh === "") {
            if (launcher.calcBusy)
                return [{ kind: "calc", title: tr("launcher.calc_busy_t", "Calculando…"), sub: "qalc", iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: "" }];
            return [{ kind: "calc", title: tr("launcher.calc_empty_t", "Escribe una operación"), sub: tr("launcher.calc_empty_s", "ej: 45*1.21 · sqrt(2) · 100 EUR to USD"), iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: "" }];
        }
        return [{ kind: "calc", title: q.trim() + " = " + fresh, sub: tr("launcher.calc_copy", "Enter copia el resultado"), iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: fresh }];
    }

    function webResults(q) {
        const cat = tr("launcher.cat_web", "Web");
        if (q === "")
            return [{ kind: "web", title: tr("launcher.web_empty_t", "Escribe para buscar"), sub: tr("launcher.web_empty_s", "Búsqueda web DuckDuckGo"), iconName: "search", appIcon: "", ch: "", imagePath: "", cat: cat, url: "" }];
        const out = [];
        if (launcher.isUrl(q)) {
            const url = (q.startsWith("http") ? q : "https://" + q);
            out.push({ kind: "web", title: "Abrir " + url, sub: tr("launcher.web_open_s", "Abrir URL en navegador"), iconName: "open_in_new", appIcon: "", ch: "", imagePath: "", cat: cat, url: url });
        }
        out.push({ kind: "web", title: tr("launcher.web_search_pre", "Buscar “") + q + tr("launcher.web_search_post", "”"), sub: tr("launcher.web_empty_s", "Búsqueda web DuckDuckGo"), iconName: "search", appIcon: "", ch: "", imagePath: "", cat: cat,
                   url: "https://duckduckgo.com/?q=" + encodeURIComponent(q) + "&ia=web" });
        return out;
    }

    // ---------- búsqueda de archivos con fd ----------
    // Recursiva por todo $HOME hasta llegar a los archivos (--max-results
    // corta en cuanto se llena: el escaneo es instantáneo aunque el home
    // sea enorme). --fixed-strings para que lo tecleado se busque literal
    // (los puntos y símbolos son texto, no regex).
    readonly property var fileExcludes: [
        ".git", ".cache", ".local", ".var", ".cargo", ".npm", ".bun",
        ".gradle", ".pub-cache", ".dart-tool", ".mozilla", ".floorp",
        ".thunderbird", ".wine", ".steam", ".stremio-server", ".bitmonero",
        ".vscode-oss", ".vscode-oss-shared", ".renpy", ".vm-space", ".java",
        "node_modules", "__pycache__", ".venv"
    ]

    function fdCommand(home, query) {
        const cmd = ["fd", "--type", "f"];
        for (let i = 0; i < fileExcludes.length; i++)
            cmd.push("--exclude", fileExcludes[i]);
        if (query === "") {
            // Sin query: solo visibles (los directorios útiles de la home)
            // en recursivo. Sin patrón `fd` tomaría $HOME como patrón y no
            // devolvería nada, así que se usa match-all ".".
            cmd.push("--max-results", "200", ".", home);
        } else {
            // Con query: todo incluido ocultos, en literal.
            cmd.push("--hidden", "--fixed-strings", "--max-results", "100", query, home);
        }
        return cmd;
    }

    Timer {
        id: fileDebounce
        interval: 250
        onTriggered: {
            if (launcher.activeMode !== "files" || !launcher.launcherVisible)
                return;
            fileProc.command = launcher.fdCommand(Quickshell.env("HOME"), launcher.query);
            fileProc.running = true;
        }
    }

    Process {
        id: fileProc
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "" || fileResults.count >= 200)
                    return;
                const name = line.split("/").pop();
                fileResults.append({ path: line, name: name, isDir: line.endsWith("/") });
            }
        }
        onRunningChanged: {
            if (running)
                fileResults.clear();
        }
        onExited: {
            const out = [];
            for (let i = 0; i < fileResults.count; i++) {
                const e = fileResults.get(i);
                out.push({ path: e.path, name: e.name, isDir: e.isDir });
            }
            fileSnapshot = out;
        }
    }

    onQueryChanged: {
        if (!launcherVisible)
            return;
        if (activeMode === "files")
            fileDebounce.restart();
        else if (activeMode === "calc")
            calcDebounce.restart();
    }

    // ---------- preview de imagen del clipboard ----------
    property string previewCid: ""
    property bool previewOk: false
    property string previewPath: ""
    property string previewFile: ""
    property string previewText: ""
    // Texto completo del item de clipboard seleccionado (vía decode;
    // `cliphist list` solo trae la primera línea truncada).
    property string clipTextCid: ""
    property string clipText: ""

    Connections {
        target: Services.ClipboardService
        function onPreviewReady(cid) {
            if (cid === launcher.previewCid)
                launcher.previewOk = true;
        }
        function onTextReady(cid) {
            if (cid === launcher.clipTextCid)
                launcher.clipText = Services.ClipboardService.textContent;
        }
    }

    Connections {
        target: FilePreviewService
        function onReady(path, image) {
            if (path === launcher.previewFile && image !== "") {
                launcher.previewPath = image;
                launcher.previewOk = true;
            }
        }
        function onTextReady(path, text) {
            if (path === launcher.previewFile)
                launcher.previewText = text;
        }
    }

    // ¿El item tiene preview con imagen diferida (clipboard / audio / video / pdf)?
    function hasLivePreview(cur) {
        if (!cur)
            return false;
        if (cur.kind === "clip" && cur.isImage)
            return true;
        if (cur.kind === "file" && (cur.media === "audio" || cur.media === "video" || cur.media === "pdf"))
            return true;
        return false;
    }

    // ¿El item previsualiza texto (ficheros de texto)?
    function hasTextPreview(cur) {
        return cur && cur.kind === "file" && cur.media === "text";
    }

    // ¿Es un texto del portapapeles? Tiene preview propia de texto completo
    // (sin icono grande ni título duplicado: el cuerpo ya es el texto).
    function isClipText(cur) {
        return cur && cur.kind === "clip" && !cur.isImage;
    }

    // Preview diferido: al moverse rápido por la lista (↑/↓, hover, filtrado)
    // solo se genera el del item donde se asienta la selección (~120 ms).
    // Lo barato (limpiar al caer en un item sin preview) es inmediato para
    // no retrasar el panel. Ver FilePreviewService (además mata lo obsoleto).
    property int previewPendingIndex: -1

    function schedulePreview() {
        const item = resultList.currentItem ? resultList.currentItem.modelData : null;
        if (!MenuModes.supportsPreview(launcher.activeMode) || !MenuModes.needsPreview(launcher.activeMode, item)) {
            previewDebounce.stop();
            previewPendingIndex = -1;
            updatePreview(item);
            return;
        }
        previewPendingIndex = resultList.currentIndex;
        previewDebounce.restart();
    }

    Timer {
        id: previewDebounce

        interval: 120
        onTriggered: {
            // Solo si la selección sigue donde estaba al programar: si se
            // movió, ya hay otra llamada en camino y esta queda obsoleta.
            // Se lee el item fresco (el objeto puede haberse reconstruido).
            if (launcher.previewPendingIndex === resultList.currentIndex)
                launcher.updatePreview(resultList.currentItem ? resultList.currentItem.modelData : null);
            launcher.previewPendingIndex = -1;
        }
    }

    function updatePreview(item) {        // Preview solo donde es imprescindible (ver MenuModes.js):
        // clip siempre, files/system solo si el item trae imagen o texto.
        // En el resto de menús no se pide ni se muestra nada.
        if (!MenuModes.supportsPreview(launcher.activeMode) || !MenuModes.needsPreview(launcher.activeMode, item)) {
            previewOk = false;
            previewCid = "";
            previewPath = "";
            previewFile = "";
            previewText = "";
            clipTextCid = "";
            clipText = "";
            return;
        }
        // Ya visible para este mismo item: no recargar (evita parpadeo).
        if (item && previewOk) {
            if ((item.kind === "clip" && item.isImage && item.cid === previewCid)
                || (item.kind === "file" && (item.media === "audio" || item.media === "video" || item.media === "pdf") && item.path === previewFile))
                return;
        }
        if (item && item.kind === "file" && item.media === "text" && item.path === previewFile && previewText !== "")
            return;
        previewOk = false;
        previewCid = "";
        previewPath = "";
        previewFile = "";
        previewText = "";
        clipTextCid = "";
        clipText = "";
        if (!item)
            return;
        if (item.kind === "clip" && item.isImage) {
            previewCid = item.cid;
            previewPath = Services.ClipboardService.previewImage(item.cid);
        } else if (launcher.isClipText(item)) {
            // Texto completo vía decode (con fallback a la línea del listado
            // mientras llega). Sin previewOk: el cuerpo se muestra en cuanto
            // hay algo que enseñar.
            clipTextCid = item.cid;
            clipText = Services.ClipboardService.requestText(item.cid);
        } else if (item.kind === "file" && (item.media === "audio" || item.media === "video" || item.media === "pdf")) {
            previewFile = item.path;
            FilePreviewService.request(item.path, item.media);
        } else if (item.kind === "file" && item.media === "text") {
            previewFile = item.path;
            FilePreviewService.requestText(item.path);
        }
    }

    // ---------- UI ----------
    SurfaceBackground {
        id: background

        // Menú por defecto más estrecho; ancho completo solo con preview.
        width: previewPanel.hasPreview ? 900 : 600
        height: 640
        Behavior on width {
            NumberAnimation {
                duration: 150
            }
        }
        anchors.centerIn: parent
        color: Appearance.md3.surface
        radius: 28

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            MaterialTextField {
                id: searchField

                Layout.fillWidth: true
                selectedTextColor: Appearance.md3.on_primary
                selectionColor: Appearance.md3.primary
                focus: true
                placeholderText: {
                    switch (launcher.activeMode) {
                    case "system": return tr("launcher.ph_system", "Sistema… (> para este modo)");
                    case "files": return tr("launcher.ph_files", "Archivos en $HOME…");
                    case "web": return tr("launcher.ph_web", "Buscar en DuckDuckGo…");
                    case "emoji": return tr("launcher.ph_emoji", "Emojis y símbolos… (g:grupo · Ctrl+Mayús+F favorito)");
                    case "calc": return tr("launcher.ph_calc", "Calculadora… ej: 45*1.21");
                    case "clip": return tr("launcher.ph_clip", "Portapapeles (cliphist)…");
                    default: return tr("launcher.ph_todo", "Buscar aplicaciones…");
                    }
                }

                // Sin carácter de menú → volver al menú por defecto.
                onTextChanged: {
                    if (launcher.forcedMode !== "" && !text.startsWith(launcher.prefixOf(launcher.forcedMode)))
                        launcher.forcedMode = "";
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const shift = event.modifiers & Qt.ShiftModifier;
                    if (ctrl && shift && event.key === Qt.Key_P) {
                        // Fija/quita la app seleccionada (solo modo todo).
                        // Va antes del Ctrl+P de navegación: lleva Shift.
                        launcher.togglePinCurrent();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && shift && event.key === Qt.Key_F) {
                        // Marca/desmarca el emoji seleccionado como favorito.
                        launcher.toggleFavCurrent();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
                        launcher.moveSelection(1);
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                        launcher.moveSelection(-1);
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_Escape:
                        // ESC sale del menú directamente.
                        launcher.launcherVisible = false;
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        launcher.moveSelection(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        launcher.moveSelection(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Tab:
                        // Rota de modo
                        cycleMode(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Backspace:
                        // En modo sistema con query vacía: subir de sección.
                        if (launcher.activeMode === "system" && launcher.query === "") {
                            const parent = SystemMenuRegistry.sectionInfo(launcher.menuSection).parentId;
                            if (parent !== "") {
                                launcher.goSection(parent);
                                event.accepted = true;
                            }
                        }
                        break;
                    case Qt.Key_Delete:
                        if (launcher.activeMode === "clip") {
                            const cur = resultList.currentItem;
                            if (cur && cur.modelData)
                                Services.ClipboardService.deleteEntry(cur.modelData.cid);
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        launcher.activateCurrent();
                        event.accepted = true;
                        break;
                    }
                }
            }

            // Pestañas de modo (equivale a los prefijos).
            // Fila con scroll horizontal: los chips conservan su ancho natural
            // y no se aplastan cuando el menú está estrecho (600px).
            Flickable {
                id: modeScroller

                Layout.fillWidth: true
                height: 32
                contentWidth: modeRow.implicitWidth
                contentHeight: 32
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width

                // Rueda vertical -> desplazamiento horizontal.
                WheelHandler {
                    orientation: Qt.Vertical
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                        const maxX = Math.max(0, modeScroller.contentWidth - modeScroller.width);
                        modeScroller.contentX = Math.min(maxX, Math.max(0, modeScroller.contentX - d));
                    }
                }

                Row {
                    id: modeRow

                    spacing: 6
                    height: 32

                    Repeater {
                        id: modeRepeater

                        model: launcher.modes
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            property bool isActive: launcher.activeMode === modelData.modeId

                            // Ancho según contenido: sin aplastamiento.
                            width: Math.max(64, chipText.implicitWidth + 26)
                            height: 30
                            radius: 15
                            color: isActive ? Appearance.md3.secondary_container : "transparent"
                            border.width: isActive ? 0 : 1
                            border.color: Appearance.md3.outline_variant

                            StyledText {
                                id: chipText

                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - 14)
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                // Carácter selector del menú entre corchetes: teclearlo cambia de menú.
                                text: (modelData.selectorChar !== "" ? "[" + modelData.selectorChar + "] " : "") + launcher.modeLabel(modelData.modeId)
                                font.pixelSize: 12
                                color: parent.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.modeId === "todo") {
                                        launcher.forcedMode = "";
                                        searchField.text = "";
                                    } else if (modelData.modeId === "system") {
                                        launcher.forcedMode = "";
                                        launcher.goSection("main");
                                    } else {
                                        launcher.forcedMode = "";
                                        searchField.text = modelData.selectorChar;
                                    }
                                    searchField.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Mantiene visible el chip activo al cambiar de modo.
                Connections {
                    target: launcher
                    function onActiveModeChanged() {
                        Qt.callLater(() => {
                            let x = 0;
                            for (let i = 0; i < modeRepeater.count; i++) {
                                const item = modeRepeater.itemAt(i);
                                if (launcher.modes[i].modeId === launcher.activeMode) {
                                    const maxX = Math.max(0, modeScroller.contentWidth - modeScroller.width);
                                    if (x < modeScroller.contentX)
                                        modeScroller.contentX = x;
                                    else if (x + (item ? item.width : 0) > modeScroller.contentX + modeScroller.width)
                                        modeScroller.contentX = Math.min(maxX, Math.max(0, x + (item ? item.width : 0) - modeScroller.width));
                                    break;
                                }
                                x += (item ? item.width : 0) + modeRow.spacing;
                            }
                        });
                    }
                }
            }

            // Chips de categoría del selector de emojis (grupos + Recientes
            // + Favoritos del EmojiService). Clic = alternar `g:<id>`.
            // Flow adaptable: cada chip mide según su contenido y el
            // conjunto salta de línea solo; la altura la decide el
            // contenido (sin alto fijo ni scroll).
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: launcher.activeMode === "emoji"

                Repeater {
                    model: launcher.emojiGroups
                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        property bool isActive: launcher.emojiActiveGroup() === modelData.id

                        width: Math.max(56, groupChipText.implicitWidth + 30)
                        height: 26
                        radius: 13
                        color: isActive ? Appearance.md3.secondary_container : "transparent"
                        border.width: isActive ? 0 : 1
                        border.color: Appearance.md3.outline_variant

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: modelData.icon || "circle"
                                size: 14
                                color: parent.parent.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                            }
                            StyledText {
                                id: groupChipText

                                anchors.verticalCenter: parent.verticalCenter
                                // Sin conteo: chips compactos de una fila.
                                text: modelData.label
                                font.pixelSize: 12
                                color: parent.parent.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.toggleEmojiGroup(modelData.id)
                        }
                    }
                }
            }

            // Miga de pan del menú de sistema (navegación estilo Omarchy)
            Row {
                Layout.fillWidth: true
                spacing: 4
                visible: launcher.activeMode === "system"

                Repeater {
                    id: crumbRepeater

                    model: SystemMenuRegistry.trail(launcher.menuSection)

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        property bool isLast: index === crumbRepeater.count - 1

                        height: 26
                        width: crumbLabel.implicitWidth + 22
                        radius: 13
                        color: isLast ? Appearance.md3.primary_container : "transparent"

                        StyledText {
                            id: crumbLabel

                            anchors.centerIn: parent
                            text: (index > 0 ? "› " : "") + modelData.title
                            font.pixelSize: 12
                            color: parent.isLast ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.goSection(modelData.sectionId)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: previewPanel.hasPreview ? 12 : 0

                // ---- lista ----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 460

                    ListView {
                        id: resultList

                        anchors.fill: parent
                        clip: true
                        spacing: 4
                        // Delegados ya instanciados fuera de vista (~4 por lado):
                        // scroll rápido sin crear/destruir en cada frame.
                        cacheBuffer: 224
                        currentIndex: count > 0 ? 0 : -1
                        highlightMoveDuration: 100
                        keyNavigationEnabled: false
                        // Modo todo: ScriptModel vivo de DesktopEntries.
                        // Resto de modos: array plano de `results`.
                        model: launcher.activeMode === "todo" ? appModel : launcher.results

                        onCountChanged: {
                            // Tras un Supr la lista se reconstruye y el índice
                            // puede quedar fuera de rango (ej. borras la última):
                            // se recorta para no quedarse sin selección.
                            if (count > 0) {
                                if (currentIndex < 0 || currentIndex >= count)
                                    currentIndex = Math.min(Math.max(0, currentIndex), count - 1);
                                if (currentIndex === -1)
                                    currentIndex = 0;
                            }
                            // El reseteo del modelo no siempre emite currentIndexChanged
                            // (el índice puede conservar el valor) y el currentItem aún
                            // puede ser nulo: diferir para que existan los delegados.
                            // Pasa por el diferido (solo genera al asentarse).
                            Qt.callLater(() => launcher.schedulePreview());
                        }
                        onCurrentIndexChanged: launcher.schedulePreview()

                        delegate: Rectangle {
                            id: entryDelegate

                            required property var modelData
                            required property int index

                            // En modo todo el modelData es el DesktopEntry crudo
                            // (viene de appModel); en el resto, el wrapper
                            // {kind,title,sub,iconName,appIcon,ch,...} de results.
                            readonly property bool isRawApp: {
                                const d = entryDelegate.modelData;
                                return launcher.activeMode === "todo" && d && typeof d.execute === "function";
                            }
                            readonly property string dispTitle: isRawApp ? (modelData.name || "") : (modelData.title || "")
                            readonly property string dispSub: isRawApp ? (modelData.comment || modelData.id || "") : ((modelData.cat ? modelData.cat + " · " : "") + (modelData.sub || ""))
                            readonly property string dispAppIcon: isRawApp ? (modelData.icon || "") : (modelData.appIcon || "")
                            readonly property string dispIconName: modelData.iconName || "circle"
                            readonly property string dispCh: modelData.ch || ""
                            readonly property bool dispPinned: isRawApp && (modelData.id || "") !== "" && launcher.isPinned(modelData.id)

                            width: resultList.width
                            height: 56
                            radius: 16
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 12

                                // Icono según tipo
                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32

                                    AppIcon {
                                        anchors.fill: parent
                                        source: entryDelegate.dispAppIcon
                                        fallback: "image-missing"
                                        visible: entryDelegate.dispAppIcon !== ""
                                    }
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: entryDelegate.dispIconName
                                        size: 24
                                        color: Appearance.md3.primary
                                        visible: entryDelegate.dispAppIcon === "" && entryDelegate.dispCh === ""
                                    }
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: entryDelegate.dispCh
                                        font.pixelSize: 24
                                        visible: entryDelegate.dispCh !== ""
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: entryDelegate.dispTitle
                                        font.pixelSize: 14
                                        color: Appearance.md3.on_surface
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: entryDelegate.dispSub
                                        font.pixelSize: 12
                                        color: Appearance.md3.on_surface_variant
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                }

                                // Chincheta de app fijada (Alt+P)
                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    iconName: "push_pin"
                                    size: 18
                                    color: Appearance.md3.primary
                                    visible: entryDelegate.dispPinned
                                }
                            }

                            Rectangle {
                                id: stateLayer
                                anchors.fill: parent
                                radius: parent.radius
                                property bool hovered: false
                                property bool pressed: false
                                color: Appearance.md3.on_surface
                                opacity: pressed ? 0.12 : (hovered || entryDelegate.ListView.isCurrentItem) ? 0.08 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    stateLayer.hovered = true;
                                    resultList.currentIndex = entryDelegate.index;
                                }
                                onExited: stateLayer.hovered = false
                                onPressed: stateLayer.pressed = true
                                onReleased: stateLayer.pressed = false
                                onClicked: launcher.activateItem(entryDelegate.modelData)
                            }
                        }
                    }

                    // Líneas de borde al dar la vuelta a la lista (wrap).
                    // Sin MouseArea: no interceptan clics, solo se ven.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 3
                        radius: 2
                        color: Appearance.md3.primary
                        opacity: (launcher.wrapFlash && launcher.wrapDir > 0) ? 0.55 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 3
                        radius: 2
                        color: Appearance.md3.primary
                        opacity: (launcher.wrapFlash && launcher.wrapDir < 0) ? 0.55 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }

                    // Estado vacío / cargando
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: resultList.count === 0

                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 48
                            implicitHeight: 48
                            source: Quickshell.iconPath("search-none-symbolic", true)
                                    || Quickshell.iconPath("edit-find-symbolic", true)
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                if (launcher.activeMode === "clip")
                                    return Services.ClipboardService.error !== "" ? Services.ClipboardService.error : launcher.tr("launcher.empty_clipboard", "Portapapeles vacío");
                                if (launcher.activeMode === "todo" && launcher.query === "" && launcher.appCount === 0)
                                    return launcher.tr("launcher.loading_apps", "Cargando aplicaciones…");
                                return launcher.tr("launcher.empty_noresults", "Sin resultados");
                            }
                            font.pixelSize: 14
                            color: Appearance.md3.on_surface_variant
                        }
                    }
                }

                // ---- preview lateral: solo donde es imprescindible ----
                // clip (texto completo/imagen), files image/text/audio/video,
                // system con imagePath (fastfetch).
                // En el resto de menús se oculta y la lista ocupa todo el ancho.
                Rectangle {
                    id: previewPanel

                    property var cur: resultList.currentItem ? resultList.currentItem.modelData : null
                    property bool hasPreview: MenuModes.needsPreview(launcher.activeMode, cur)

                    visible: hasPreview
                    Layout.preferredWidth: hasPreview ? 380 : 0
                    Layout.fillHeight: true
                    radius: 20
                    color: Appearance.md3.surface_container_low

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        property var cur: previewPanel.cur

                        // Imagen: archivos de imagen, carátulas/thumbs multimedia o clipboard
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 340
                            Layout.preferredHeight: 300
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            // Decodificar acotado: más rápido y menos memoria.
                            sourceSize.width: 680
                            sourceSize.height: 600
                            visible: parent.cur && ((parent.cur.imagePath || "") !== "" || (launcher.hasLivePreview(parent.cur) && launcher.previewOk))
                            source: {
                                if (!parent.cur)
                                    return "";
                                if ((parent.cur.imagePath || "") !== "")
                                    return parent.cur.imagePath;
                                if (launcher.previewOk)
                                    return "file://" + launcher.previewPath;
                                return "";
                            }
                        }

                        // Icono / emoji grande cuando no hay imagen ni texto
                        // (en clip-texto se oculta: el cuerpo ya es el texto).
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 96
                            visible: parent.cur && ((parent.cur.imagePath || "") === "") && !(launcher.hasLivePreview(parent.cur) && launcher.previewOk) && !(launcher.hasTextPreview(parent.cur) && launcher.previewText !== "") && !launcher.isClipText(parent.cur)

                            AppIcon {
                                anchors.fill: parent
                                source: parent.parent.cur ? (parent.parent.cur.appIcon || "") : ""
                                fallback: "image-missing"
                                visible: parent.parent.cur && ((parent.parent.cur.appIcon || "") !== "")
                            }
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: parent.parent.cur ? (parent.parent.cur.iconName || "circle") : "circle"
                                size: 56
                                color: Appearance.md3.primary
                                visible: parent.parent.cur && ((parent.parent.cur.appIcon || "") === "") && ((parent.parent.cur.ch || "") === "")
                            }
                            StyledText {
                                anchors.centerIn: parent
                                text: parent.parent.cur ? (parent.parent.cur.ch || "") : ""
                                font.pixelSize: 56
                                visible: parent.parent.cur && ((parent.parent.cur.ch || "") !== "")
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            // En clip-texto no hay cabecera: el cuerpo ya muestra
                            // el texto completo (evita verlo dos veces).
                            visible: !(parent.cur && launcher.isClipText(parent.cur))
                            text: parent.cur ? (parent.cur.title || "") : ""
                            font.pixelSize: 14
                            color: Appearance.md3.on_surface
                        }
                        // Texto del fichero (ficheros de texto): bloque monoespaciado con scroll
                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 280
                            visible: launcher.hasTextPreview(parent.cur) && launcher.previewText !== ""
                            contentWidth: width
                            contentHeight: previewDoc.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: previewDoc

                                width: parent.width
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: {
                                    if (launcher.previewText === "QSTEXT_TOO_BIG")
                                        return launcher.tr("launcher.file_text_big", "Archivo demasiado grande para previsualizar");
                                    return launcher.previewText;
                                }
                                font.family: Appearance.font.mono
                                font.pixelSize: 11
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            // En clip-texto el cuerpo ya es el texto: sin pie duplicado.
                            visible: !(parent.cur && launcher.isClipText(parent.cur))
                            text: {
                                if (!parent.cur)
                                    return "";
                                if (parent.cur.kind === "clip" && !parent.cur.isImage)
                                    return parent.cur.fullText || parent.cur.title;
                                return parent.cur.sub || "";
                            }
                            font.pixelSize: 12
                            color: Appearance.md3.on_surface_variant
                        }
                        // Texto del portapapeles (clip texto): bloque con scroll que
                        // ocupa todo el alto libre. Muestra el decode completo en
                        // cuanto llega; mientras tanto, la línea del listado.
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: launcher.isClipText(parent.cur)
                            contentWidth: width
                            contentHeight: clipDoc.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: clipDoc

                                width: parent.width
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: launcher.clipText !== "" ? launcher.clipText : (parent.cur ? (parent.cur.fullText || parent.cur.title) : "")
                                font.pixelSize: 13
                                color: Appearance.md3.on_surface
                            }
                        }
                    }
                }
            }

            // Barra de ayuda
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tr("launcher.footer", "Enter ejecutar · Tab cambia de modo · Ctrl+Shift+P fija app · Supr borra item clipboard · Esc limpiar/cerrar")
                font.pixelSize: 11
                color: Appearance.md3.on_surface_variant
                opacity: 0.8
            }
        }
    }

    function cycleMode(dir) {
        const order = launcher.modes.map(m => m.modeId);
        let i = order.indexOf(launcher.activeMode);
        i = (i + dir + order.length) % order.length;
        if (order[i] === "system") {
            launcher.forcedMode = "";
            launcher.goSection("main");
            return;
        }
        const p = launcher.prefixOf(order[i]);
        launcher.forcedMode = "";
        searchField.text = p;
        if (order[i] === "clip")
            Services.ClipboardService.refresh();
    }
}
