// --- UnifiedLauncher (antes AppLauncher) ---
// Menú único con FuzzySearch en todo:
//   modos por prefijo:
//     (nada) todo: apps + calc + sistema + atajo web
//     >  sistema (menús personalizados: secciones MenuDefinition de
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
import "Base/MenuModes.js" as MenuModes
import "Base/LauncherApps.js" as LauncherApps
import "Modes/FileMenu.js" as FileMenu
import "Modes"
import "UI"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import M3Shapes

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
        // actualiza sola vía MenuStore.revision.
        function reloadMenus(): string {
            return SystemMenuRegistry.reloadMenus();
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
        case "todo": return tr("launcher.tab_all", "Todo");
        case "system": return tr("launcher.tab_system", "Sistema");
        case "files": return tr("launcher.tab_files", "Archivos");
        case "web": return tr("launcher.tab_web", "Web");
        case "emoji": return tr("launcher.tab_emoji", "Emojis");
        case "calc": return tr("launcher.tab_calc", "Calc");
        default: return tr("launcher.tab_clipboard", "Clipboard");
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

    // Forma-identidad por modo (hero + badges de chips).
    function modeShape(modeId) {
        switch (modeId) {
        case "system": return MaterialShape.Cookie6Sided;
        case "files": return MaterialShape.Bun;
        case "web": return MaterialShape.Oval;
        case "emoji": return MaterialShape.Flower;
        case "calc": return MaterialShape.Diamond;
        case "clip": return MaterialShape.Clover4Leaf;
        default: return MaterialShape.Circle;
        }
    }

    function modeIcon(modeId) {
        switch (modeId) {
        case "system": return "settings";
        case "files": return "folder";
        case "web": return "public";
        case "emoji": return "mood";
        case "calc": return "calculate";
        case "clip": return "content_paste";
        default: return "apps";
        }
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
            fileSearch.snapshot = [];
            preview.reset();
            // Cada apertura empieza en orden canónico (no congelado).
            launcher.frozenIds = [];
            // La selección vuelve al principio en cada apertura.
            resultList.resetView();
            // Cada apertura empieza escribiendo, no navegando.
            launcher.navResults = false;
            if (forcedMode === "clip" || forcedMode === "")
                Services.ClipboardService.refresh();
            // Modelos live del menú de sistema (búsqueda global + badges "Actual",
            // más menús propios; no-op si aún no se descubrieron).
            SystemMenuRegistry.refreshAll();
            // Generador de emojis en background (no-op tras el primero):
            // el arranque del shell ya no espera/spawnea python.
            EmojiService.ensureLib();
            searchField.forceActiveFocus();
        } else {
            forcedMode = "";
            // Sin selecciones a medias al cerrar: el diferido no debe pintar
            // nada de una sesión ya cerrada.
            preview.reset();
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

    // Mueve la selección: vive en ResultList (con el flash de borde).

    // Al entrar a modo clipboard refresca historial
    onActiveModeChanged: {
        if (launcherVisible && activeMode === "clip")
            Services.ClipboardService.refresh();
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

    // Apertura de ficheros/carpetas con comprobación + aviso.
    // Lógica en FileMenu.js (openCommand); aquí solo textos y lanzamiento.
    function openPath(path) {
        launcher.runShell(FileMenu.openCommand(path, tr("launcher.tab_files", "Archivos"), tr("launcher.file_missing", "El archivo ya no existe") + ": " + path, tr("launcher.file_open_failed", "No se pudo abrir") + ": " + path));
    }

    // Estado de navegación: false = escribiendo en el campo (las
    // flechas ←/→ mueven el cursor), true = navegando por los
    // resultados (las flechas mueven la selección). Lo pone a true
    // cualquier tecla de navegación y lo quita el escribir texto.
    property bool navResults: false

    // Estado vacío con retardo (ver onCountChanged de ResultList).
    property bool showEmpty: false

    Timer {
        id: emptyTimer

        interval: 150
        onTriggered: launcher.showEmpty = true
    }

    function activateCurrent() {
        const item = resultList.currentData;
        if (!item)
            return;
        activateItem(item);
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
            launcher.openPath(it.path);
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

    // ---------- calculadora (estado + qalc en LauncherCalc) ----------
    LauncherCalc {
        id: calcState

        query: launcher.query
        active: launcher.launcherVisible && launcher.activeMode === "calc"
    }

    function isUrl(q) {
        if (/\s/.test(q))
            return false;
        return q.startsWith("http://") || q.startsWith("https://") || (/^[a-z0-9-]+(\.[a-z0-9-]+)+/.test(q) && q.indexOf(" ") < 0);
    }

    // ---------- resultados ----------
    // Búsqueda de archivos (fd + snapshot en LauncherFileSearch).
    LauncherFileSearch {
        id: fileSearch

        query: launcher.query
        active: launcher.launcherVisible && launcher.activeMode === "files"
    }

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
        const d = resultList.currentData;
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
            return LauncherApps.alphaSort(starts);
        if (contains.length > 0)
            return LauncherApps.alphaSort(contains);
        return Services.FuzzySearch.filterItemsMulti(q, apps, e => [e.name, e.comment || "", e.id || ""]).slice(0, 15);
    }

    // Orden visual congelado al desfijar: la app se queda donde está y
    // la lista no salta hasta que se haga una búsqueda, se cambie de
    // modo, se reabra o se fije otra. Guarda IDs en orden visible.
    property var frozenIds: []

    // ---------- aplicaciones (modo todo) ----------
    // Fuente única y viva: DesktopEntries -> fijadas primero -> filtro.
    // ScriptModel re-suscribe el binding ante altas/bajas de .desktop y
    // actualiza solo los delegates que cambian, sin snapshots ni contadores.
    // Los valores son los DesktopEntry tal cual (identidad estable y
    // única, requisito del ScriptModel); el delegate los pinta directo.
    ScriptModel {
        id: appModel

        values: {
            const base = LauncherApps.uniqueApps([...DesktopEntries.applications.values]);
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
                return out.concat(LauncherApps.alphaSort(fresh));
            }
            const pool = q === "" ? LauncherApps.alphaSort(base) : launcher.todoFilter(q, base);
            return LauncherApps.pinFirst(pool, pins);
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
                kind: "menuback", title: tr("launcher.back_prefix", "Atrás · ") + parent.title,
                sub: tr("launcher.back_subtitle", "Volver a la sección anterior"), iconName: "arrow_back",
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
        const cat = tr("launcher.category_emoji", "Emoji");
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
        const d = resultList.currentData;
        if (d && d.ch)
            EmojiService.toggleFavorite(d.ch);
    }

    function clipResults(q) {
        const cat = tr("launcher.category_clipboard", "Portapapeles");
        const out = [];
        const snap = Services.ClipboardService.snapshot;
        for (let i = 0; i < snap.length; i++) {
            const e = snap[i];
            out.push({ kind: "clip", title: e.text.length > 90 ? e.text.slice(0, 90) + "…" : e.text,
                       sub: e.isImage ? tr("launcher.clip_image_subtitle", "Imagen · Enter copia · preview →") : tr("launcher.clip_text_subtitle", "Texto · Enter copia · Supr borra"),
                       iconName: e.isImage ? "image" : "content_paste", appIcon: "", ch: "",
                       imagePath: "", cat: cat, cid: e.cid, isImage: e.isImage, fullText: e.text });
        }
        if (q === "")
            return out;
        return Services.FuzzySearch.filterItems(q, out, it => it.title);
    }

    // Resultados de archivos: mapeo (FileMenu) + fuzzy. El orden base
    // ya viene ordenado del snapshot (ver LauncherFileSearch).
    function fileResultsList(q) {
        const cat = tr("launcher.category_file", "Archivo");
        const out = FileMenu.mapSnapshot(fileSearch.snapshot, cat);
        if (q === "")
            return out;
        const matches = Services.FuzzySearch.filterItemsMulti(q, out, it => [it.title, it.sub]);
        return FileMenu.nameFirst(matches, q);
    }

    function calcResults(q) {
        const cat = tr("launcher.category_calc", "Calc");
        // Solo vale el resultado pedido para este query (si tecleas rápido,
        // el anterior en vuelo se ignora al mostrar).
        const fresh = calcState.forQuery === q ? calcState.result : "";
        if (fresh === "") {
            if (calcState.busy)
                return [{ kind: "calc", title: tr("launcher.calc_busy_title", "Calculando…"), sub: "qalc", iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: "" }];
            return [{ kind: "calc", title: tr("launcher.calc_empty_title", "Escribe una operación"), sub: tr("launcher.calc_empty_subtitle", "ej: 45*1.21 · sqrt(2) · 100 EUR to USD"), iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: "" }];
        }
        return [{ kind: "calc", title: q.trim() + " = " + fresh, sub: tr("launcher.calc_copy_hint", "Enter copia el resultado"), iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: fresh }];
    }

    function webResults(q) {
        const cat = tr("launcher.category_web", "Web");
        if (q === "")
            return [{ kind: "web", title: tr("launcher.web_empty_title", "Escribe para buscar"), sub: tr("launcher.web_empty_subtitle", "Búsqueda web DuckDuckGo"), iconName: "search", appIcon: "", ch: "", imagePath: "", cat: cat, url: "" }];
        const out = [];
        if (launcher.isUrl(q)) {
            const url = (q.startsWith("http") ? q : "https://" + q);
            out.push({ kind: "web", title: "Abrir " + url, sub: tr("launcher.web_open_subtitle", "Abrir URL en navegador"), iconName: "open_in_new", appIcon: "", ch: "", imagePath: "", cat: cat, url: url });
        }
        out.push({ kind: "web", title: tr("launcher.web_search_prefix", "Buscar “") + q + tr("launcher.web_search_suffix", "”"), sub: tr("launcher.web_empty_subtitle", "Búsqueda web DuckDuckGo"), iconName: "search", appIcon: "", ch: "", imagePath: "", cat: cat,
                   url: "https://duckduckgo.com/?q=" + encodeURIComponent(q) + "&ia=web" });
        return out;
    }

    // (Búsqueda de archivos y calculadora: debounce + procesos viven en
    // LauncherFileSearch / LauncherCalc y se auto-disparan por
    // query/active. Aquí no queda nada que reiniciar a mano.)

    // ---------- preview lateral (estado + debounce en LauncherPreview) ----------
    LauncherPreview {
        id: preview

        activeMode: launcher.activeMode
        currentIndex: resultList.currentIndex
        currentItem: resultList.currentData
    }

    // Predicados de items en Base/ItemKinds.js (los usa PreviewPanel).

    // ---------- UI ----------
    SurfaceBackground {
        id: background

        // Accessible en el contenido (Item), no en la PanelWindow.
        Accessible.role: Accessible.Dialog
        Accessible.name: tr("launcher.placeholder_all", "Buscar aplicaciones…")

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

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Hero expresivo: morfea con el modo activo.
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44

                    MaterialShape {
                        anchors.fill: parent
                        shape: launcher.modeShape(launcher.activeMode)
                        animationDuration: 350
                        color: Appearance.md3.primary_container

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: launcher.modeIcon(launcher.activeMode)
                            size: Appearance.font.pixelSize.large
                            color: Appearance.md3.on_primary_container
                        }
                    }
                }

                MaterialTextField {
                    id: searchField

                    Layout.fillWidth: true
                    // TextField ya expone rol EditableText; el nombre sigue
                    // al placeholder del modo activo.
                    Accessible.name: searchField.placeholderText
                selectedTextColor: Appearance.md3.on_primary
                selectionColor: Appearance.md3.primary
                focus: true
                placeholderText: {
                    switch (launcher.activeMode) {
                    case "system": return tr("launcher.placeholder_system", "Sistema… (> para este modo)");
                    case "files": return tr("launcher.placeholder_files", "Archivos en $HOME…");
                    case "web": return tr("launcher.placeholder_web", "Buscar en DuckDuckGo…");
                    case "emoji": return tr("launcher.placeholder_emoji", "Emojis y símbolos… (g:grupo · Ctrl+Mayús+F favorito)");
                    case "calc": return tr("launcher.placeholder_calc", "Calculadora… ej: 45*1.21");
                    case "clip": return tr("launcher.placeholder_clipboard", "Portapapeles (cliphist)…");
                    default: return tr("launcher.placeholder_all", "Buscar aplicaciones…");
                    }
                }

                // Sin carácter de menú → volver al menú por defecto.
                onTextChanged: {
                    // Escribir vuelve a modo texto (flechas al cursor).
                    launcher.navResults = false;
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
                        // En cuadrícula: abajo (una fila); en lista: siguiente.
                        launcher.navResults = true;
                        if (resultList.isGrid)
                            resultList.moveGrid(0, 1);
                        else
                            resultList.moveSelection(1);
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                        // En cuadrícula: arriba (una fila); en lista: anterior.
                        launcher.navResults = true;
                        if (resultList.isGrid)
                            resultList.moveGrid(0, -1);
                        else
                            resultList.moveSelection(-1);
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && event.key === Qt.Key_F) {
                        // En cuadrícula: derecha. En lista se deja pasar
                        // al campo (mover cursor).
                        if (resultList.isGrid) {
                            launcher.navResults = true;
                            resultList.moveGrid(1, 0);
                            event.accepted = true;
                            return;
                        }
                    }
                    if (ctrl && event.key === Qt.Key_B) {
                        // En cuadrícula: izquierda. En lista, al campo.
                        if (resultList.isGrid) {
                            launcher.navResults = true;
                            resultList.moveGrid(-1, 0);
                            event.accepted = true;
                            return;
                        }
                    }
                    switch (event.key) {
                    case Qt.Key_Escape:
                        // ESC sale del menú directamente.
                        launcher.launcherVisible = false;
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                        // Navegando: siempre a resultados. Escribiendo: solo
                        // al borde izquierdo; si no, el campo mueve el cursor.
                        // En lista, siempre al campo.
                        if (resultList.isGrid && (launcher.navResults || (searchField.cursorPosition === 0 && searchField.selectedText === ""))) {
                            launcher.navResults = true;
                            resultList.moveGrid(-1, 0);
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_Right:
                        // Simétrico al borde derecho.
                        if (resultList.isGrid && (launcher.navResults || (searchField.cursorPosition >= searchField.length && searchField.selectedText === ""))) {
                            launcher.navResults = true;
                            resultList.moveGrid(1, 0);
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_Down:
                        launcher.navResults = true;
                        if (resultList.isGrid)
                            resultList.moveGrid(0, 1);
                        else
                            resultList.moveSelection(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        launcher.navResults = true;
                        if (resultList.isGrid)
                            resultList.moveGrid(0, -1);
                        else
                            resultList.moveSelection(-1);
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
                            const d = resultList.currentData;
                            if (d && d.cid)
                                Services.ClipboardService.deleteEntry(d.cid);
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
                            id: chipRect

                            required property var modelData
                            required property int index

                            property bool isActive: launcher.activeMode === modelData.modeId

                            // Ancho según contenido: sin aplastamiento.
                            width: Math.max(64, chipRow.implicitWidth + 26)
                            height: 30
                            radius: 15
                            color: isActive ? Appearance.md3.secondary_container : "transparent"
                            border.width: isActive ? 0 : 1
                            border.color: Appearance.md3.outline_variant

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 6

                                // Badge expresivo con la forma-identidad del modo.
                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 22
                                    implicitHeight: 22

                                    MaterialShape {
                                        anchors.fill: parent
                                        shape: launcher.modeShape(modelData.modeId)
                                        animationDuration: 300
                                        color: chipRect.isActive ? Appearance.md3.primary : Appearance.md3.surface_container_highest

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            icon: launcher.modeIcon(modelData.modeId)
                                            size: 13
                                            color: chipRect.isActive ? Appearance.md3.on_primary : Appearance.md3.on_surface_variant
                                        }
                                    }
                                }

                                StyledText {
                                    id: chipText

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.parent.width - 50)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    // Carácter selector del menú entre corchetes: teclearlo cambia de menú.
                                    text: (modelData.selectorChar !== "" ? "[" + modelData.selectorChar + "] " : "") + launcher.modeLabel(modelData.modeId)
                                    font.pixelSize: 12
                                    color: chipRect.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                                }
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

                    ResultList {
                        id: resultList

                        anchors.fill: parent
                        // Modo todo: ScriptModel vivo de DesktopEntries.
                        // Resto de modos: array plano de `results`.
                        listModel: launcher.activeMode === "todo" ? appModel : launcher.results
                        activeMode: launcher.activeMode
                        isPinnedFn: appId => launcher.isPinned(appId)
                        onActivated: item => launcher.activateItem(item)
                        onHighlighted: preview.schedule()
                        onCountChanged: {
                            // Estado vacío con retardo: los reseteos en caliente
                            // pasan por count 0 un instante; solo es vacío real
                            // si se mantiene.
                            if (resultList.count === 0)
                                emptyTimer.restart();
                            else {
                                emptyTimer.stop();
                                launcher.showEmpty = false;
                            }
                        }
                    }

                    // Estado vacío / cargando
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: resultList.count === 0 && launcher.showEmpty

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
                                    return Services.ClipboardService.error !== "" ? Services.ClipboardService.error : launcher.tr("launcher.clipboard_empty", "Portapapeles vacío");
                                if (launcher.activeMode === "files" && fileSearch.failed)
                                    return launcher.tr("launcher.files_fd_missing", "Búsqueda no disponible (¿fd instalado?)");
                                if (launcher.activeMode === "todo" && launcher.query === "" && launcher.appCount === 0)
                                    return launcher.tr("launcher.loading_apps", "Cargando aplicaciones…");
                                return launcher.tr("launcher.empty_no_results", "Sin resultados");
                            }
                            font.pixelSize: 14
                            color: Appearance.md3.on_surface_variant
                        }
                    }
                }

                // ---- preview lateral (ver PreviewPanel) ----
                PreviewPanel {
                    id: previewPanel

                    activeMode: launcher.activeMode
                    cur: resultList.currentData
                    previewOk: preview.previewOk
                    previewPath: preview.previewPath
                    previewText: preview.previewText
                    clipText: preview.clipText
                    fileTooLargeText: tr("launcher.file_too_large", "Archivo demasiado grande para previsualizar")
                }
            }

            // Barra de ayuda
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tr("launcher.footer_hint", "Enter ejecutar · Tab cambia de modo · Ctrl+Shift+P fija app · Supr borra item clipboard · Esc limpiar/cerrar")
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
