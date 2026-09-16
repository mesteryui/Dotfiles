// --- UnifiedLauncher (antes AppLauncher) ---
// Menú único estilo Walker + datos Elephant, con FuzzySearch en todo:
//   modos por prefijo (igual que walker config.toml):
//     (nada) todo: apps + calc + sistema + atajo web
//     >  sistema (menú Omarchy: secciones de SystemMenu/*.js + live SystemMenuService)
//     /  archivos (fd en $HOME)
//     @  búsqueda web (DuckDuckGo, como websearch.toml)
//     .  emojis/símbolos (como symbols.toml -> wl-copy)
//     =  calculadora (como provider calc)
//     :  portapapeles (cliphist, texto + preview de imágenes)
// Panel derecho = preview (iconos grandes, imágenes de archivos,
// capturas del clipboard, wallpapers). Igual que walker preview.xml.
pragma ComponentBehavior: Bound
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import qs.Shared.Background
import "EmojiData.js" as EmojiData
import "EmojiFull.js" as EmojiFull
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
        function open(): void {
            launcher.forcedMode = "";
            launcher.launcherVisible = true;
        }
        // Abre con un texto de búsqueda ya puesto (respeta prefijos de modo).
        function search(text: string): void {
            launcher.forcedMode = "";
            launcher.launcherVisible = true;
            searchField.text = text || "";
        }
        function close(): void {
            launcher.launcherVisible = false;
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
            launcher.menuSection = target;
            launcher.forcedMode = "system";
            launcher.launcherVisible = true;
        }
        function openFiles(query: string): void {
            if (launcher.launcherVisible && launcher.activeMode === "files") {
                launcher.launcherVisible = false;
                return;
            }
            launcher.forcedMode = "files";
            launcher.launcherVisible = true;
            searchField.text = "/" + (query || "");
        }
        // Toggle por menú: si ya está abierto en ese menú, cierra; si no, abre.
        function toggleMode(name: string): void {
            const m = name || "todo";
            const cur = launcher.forcedMode !== "" ? launcher.forcedMode : launcher.activeMode;
            if (launcher.launcherVisible && cur === m) {
                launcher.launcherVisible = false;
                return;
            }
            if (m === "system")
                launcher.menuSection = "main";
            launcher.forcedMode = (m === "todo") ? "" : m;
            launcher.launcherVisible = true;
        }
    }

    // ---------- modos (mismos prefijos que walker) ----------
    readonly property var modes: [
        { id: "todo", pfx: "" },
        { id: "system", pfx: ">" },
        { id: "files", pfx: "/" },
        { id: "web", pfx: "@" },
        { id: "emoji", pfx: "." },
        { id: "calc", pfx: "=" },
        { id: "clip", pfx: ":" }
    ]

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
    property int appCount: DesktopEntries.applications.values.length

    function prefixOf(modeId) {
        for (let i = 0; i < modes.length; i++)
            if (modes[i].id === modeId)
                return modes[i].pfx;
        return "";
    }

    // Prefijo tecleado (tiene prioridad: los caracteres siempre cambian de menú)
    function typedMode() {
        const t = searchField.text;
        if (t.length > 0) {
            for (let i = 0; i < modes.length; i++) {
                const p = modes[i].pfx;
                if (p !== "" && t.startsWith(p))
                    return modes[i].id;
            }
        }
        return "";
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
            if (forcedMode === "clip" || forcedMode === "")
                Services.ClipboardService.refresh();
            // Modelos live del menú de sistema (búsqueda global + badges "Actual")
            SystemMenuService.refreshAll();
            searchField.forceActiveFocus();
        } else {
            forcedMode = "";
        }
    }

    // Entrar a una sección (click, breadcrumb, IPC): refresca si es dinámica.
    function goSection(id) {
        menuSection = id;
        searchField.text = ">";
        if (SystemMenuRegistry.isDynamic(id))
            SystemMenuService.refreshSection(id);
        searchField.forceActiveFocus();
    }

    // Mueve la selección con cycle: del último vuelve al primero y viceversa.
    function moveSelection(delta) {
        const n = resultList.count;
        if (n === 0)
            return;
        let i = resultList.currentIndex + delta;
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
    }

    // ---------- helpers ----------
    function shellEscape(s) {
        return s.replace(/'/g, "'\\''");
    }

    property var pendingCmd: ["true"]
    function runCmd(cmd) {
        pendingCmd = cmd;
        runProc.running = true;
    }

    Process {
        id: runProc
        command: launcher.pendingCmd
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("Launcher: falló", JSON.stringify(launcher.pendingCmd));
        }
    }

    function activateCurrent() {
        const item = resultList.currentItem;
        if (!item || !item.modelData)
            return;
        activateItem(item.modelData);
    }

    function activateItem(it) {
        // Navegación entre secciones: no cierra el menú.
        if (it.kind === "menuback" || (it.kind === "system" && it.isSubmenu)) {
            launcher.goSection(it.section);
            return;
        }
        switch (it.kind) {
        case "app":
            if (it.entry.runInTerminal)
                Quickshell.execDetached({
                    command: ["xdg-terminal-exec", "-e"].concat(it.entry.command),
                    workingDirectory: it.entry.workingDirectory
                });
            else
                it.entry.execute();
            break;
        case "system":
            if (it.nativeApply === "power")
                SystemMenuService.applyPowerProfile(it.nativeValue);
            else
                launcher.runCmd(["sh", "-c", it.shell]);
            break;
        case "emoji":
            launcher.runCmd(["sh", "-c", "printf '%s' '" + launcher.shellEscape(it.ch) + "' | wl-copy"]);
            break;
        case "clip":
            Services.ClipboardService.copyEntry(it.cid, it.isImage);
            break;
        case "file":
            launcher.runCmd(["xdg-open", it.path]);
            break;
        case "calc":
            launcher.runCmd(["sh", "-c", "printf '%s' '" + launcher.shellEscape(it.result) + "' | wl-copy"]);
            break;
        case "web":
            launcher.runCmd(["xdg-open", it.url]);
            break;
        }
        launcher.launcherVisible = false;
    }

    // ---------- calculadora (provider calc de walker) ----------
    function calcEval(q) {
        const t = q.trim().replace(/\s+/g, "");
        if (t === "" || !/^[0-9+\-*/%^().,a-z]+$/.test(t))
            return null;
        if (!/[0-9]/.test(t))
            return null;
        try {
            let e = t.replace(/\^/g, "**").replace(/,/g, ".");
            e = e.replace(/\bpi\b/g, "Math.PI").replace(/\be\b/g, "Math.E");
            e = e.replace(/\bsqrt\(/g, "Math.sqrt(").replace(/\bsin\(/g, "Math.sin(")
                 .replace(/\bcos\(/g, "Math.cos(").replace(/\btan\(/g, "Math.tan(")
                 .replace(/\blog\(/g, "Math.log10(").replace(/\bln\(/g, "Math.log(");
            if (/[^0-9+\-*/%().MathPIEsqrtcotalgn ]/.test(e))
                return null;
            const v = Function("\"use strict\";return (" + e + ")")();
            if (typeof v !== "number" || !isFinite(v))
                return null;
            return String(Math.round(v * 1e10) / 1e10);
        } catch (err) {
            return null;
        }
    }

    function isUrl(q) {
        if (/\s/.test(q))
            return false;
        return q.startsWith("http://") || q.startsWith("https://") || (/^[a-z0-9-]+(\.[a-z0-9-]+)+/.test(q) && q.indexOf(" ") < 0);
    }

    // ---------- resultados ----------
    property var emojiList: EmojiData.getEmojis()
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
        return todoResults(q);
    }

    function appItem(e) {
        return { kind: "app", title: e.name, sub: e.comment || e.id || "", entry: e,
                 iconName: "", appIcon: e.icon, ch: "", imagePath: "", cat: "" };
    }

    // Entradas dinámicas de una sección (snapshot de SystemMenuService).
    // Se lee el snapshot y NO los ListModel en vivo: esos notifican por cada
    // item y reevaluar `results` con cada append disparaba binding loops.
    // withCat=false al navegar (el breadcrumb ya indica la sección).
    function dynamicItems(id, withCat) {
        const info = SystemMenuRegistry.sectionInfo(id);
        const snap = SystemMenuService.dynSnapshot;
        const out = [];
        for (let i = 0; i < snap.length; i++) {
            const e = snap[i];
            if (e.section !== id)
                continue;
            out.push({
                kind: "system", title: e.title, sub: e.sub,
                iconName: e.iconName, appIcon: "", ch: "",
                imagePath: (e.preview && e.preview !== "") ? ("file://" + e.preview) : "",
                cat: withCat === false ? "" : info.title,
                shell: e.native ? "" : SystemMenuService.shellFor(id, e.value),
                nativeApply: e.native || "", nativeValue: e.nativeValue,
                isSubmenu: false, section: ""
            });
        }
        return out;
    }

    // Contenido de una sección para navegar (estáticas + dinámicas, sin prefijo cat).
    function sectionItems(id) {
        const info = SystemMenuRegistry.sectionInfo(id);
        const out = [];
        if (info.parent !== "") {
            const parent = SystemMenuRegistry.sectionInfo(info.parent);
            out.push({
                kind: "menuback", title: tr("launcher.back_pre", "Atrás · ") + parent.title,
                sub: tr("launcher.back_sub", "Volver a la sección anterior"), iconName: "arrow_back",
                appIcon: "", ch: "", imagePath: "", cat: "",
                shell: "", isSubmenu: false, section: info.parent
            });
        }
        const statics = SystemMenuRegistry.staticEntries(id);
        for (let i = 0; i < statics.length; i++)
            out.push(SystemMenuRegistry.toResultItem(statics[i], ""));
        return out.concat(dynamicItems(id, false));
    }

    // Todo lo buscable del menú de sistema (búsqueda global con query).
    function systemPool() {
        let pool = SystemMenuRegistry.flattenStatic();
        const ids = ["powerprofiles", "fastfetch", "animations"];
        for (let k = 0; k < ids.length; k++)
            pool = pool.concat(dynamicItems(ids[k]));
        return pool;
    }

    function systemResults(q) {
        // Sin query → navegación por secciones estilo Omarchy.
        if (q === "")
            return sectionItems(launcher.menuSection);
        return Services.FuzzySearch.filterItemsMulti(q, systemPool(), it => [it.title, it.sub, it.cat]);
    }

    function emojiItem(e) {
        return { kind: "emoji", title: e.ch + "  " + e.name, sub: e.kw, iconName: "",
                 appIcon: "", ch: e.ch, imagePath: "", cat: tr("launcher.cat_emoji", "Emoji") };
    }

    function emojiResults(q) {
        // Curados (español) primero, luego catálogo completo estilo elephant.
        const curated = launcher.emojiList.map(emojiItem);
        const seen = {};
        for (let i = 0; i < curated.length; i++)
            seen[launcher.emojiList[i].ch] = true;
        const full = [];
        const all = EmojiFull.getEmojis();
        for (let j = 0; j < all.length; j++)
            if (!seen[all[j].ch])
                full.push(emojiItem(all[j]));
        const items = curated.concat(full);
        if (q === "")
            return items.slice(0, 60);
        return Services.FuzzySearch.filterItemsMulti(q, items, it => [it.title, it.sub]).slice(0, 60);
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
        return Services.FuzzySearch.filterItemsMulti(q, out, it => [it.title, it.sub]);
    }

    function calcResults(q) {
        const cat = tr("launcher.cat_calc", "Calc");
        const r = launcher.calcEval(q);
        if (r === null)
            return [{ kind: "calc", title: tr("launcher.calc_empty_t", "Escribe una operación"), sub: tr("launcher.calc_empty_s", "ej: 45*1.21 · sqrt(2) · =prefijo calc"), iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: "" }];
        return [{ kind: "calc", title: q + " = " + r, sub: tr("launcher.calc_copy", "Enter copia el resultado"), iconName: "calculate", appIcon: "", ch: "", imagePath: "", cat: cat, result: r }];
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

    function todoResults(q) {
        // Menú Todo: solo aplicaciones (cada menú busca en lo suyo).
        const apps = DesktopEntries.applications.values;
        if (q === "") {
            let out = [];
            for (let i = 0; i < apps.length; i++)
                out.push(appItem(apps[i]));
            return out;
        }
        const mApps = Services.FuzzySearch.filterMulti(q, apps, e => [e.name, e.comment || "", e.id || ""]);
        let out = [];
        for (let i = 0; i < mApps.length; i++)
            out.push(appItem(mApps[i].item));
        return out;
    }

    // ---------- búsqueda de archivos con fd (provider files de walker) ----------
    Timer {
        id: fileDebounce
        interval: 250
        onTriggered: {
            if (launcher.activeMode !== "files" || !launcher.launcherVisible)
                return;
            const home = Quickshell.env("HOME");
            const q = launcher.query;
            if (q === "")
                fileProc.command = ["fd", "--max-depth", "2", "--max-results", "50", ".", home];
            else
                fileProc.command = ["fd", "--hidden", "--exclude", ".git", "--max-results", "60", q, home];
            fileProc.running = true;
        }
    }

    Process {
        id: fileProc
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "" || fileResults.count >= 80)
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
        if (launcherVisible && activeMode === "files")
            fileDebounce.restart();
    }

    // ---------- preview de imagen del clipboard ----------
    property string previewCid: ""
    property bool previewOk: false
    property string previewPath: ""
    property string previewFile: ""
    property string previewText: ""

    Connections {
        target: Services.ClipboardService
        function onPreviewReady(cid) {
            if (cid === launcher.previewCid)
                launcher.previewOk = true;
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

    // ¿El item tiene preview con imagen diferida (clipboard / audio / video)?
    function hasLivePreview(cur) {
        if (!cur)
            return false;
        if (cur.kind === "clip" && cur.isImage)
            return true;
        if (cur.kind === "file" && (cur.media === "audio" || cur.media === "video"))
            return true;
        return false;
    }

    // ¿El item previsualiza texto (ficheros de texto)?
    function hasTextPreview(cur) {
        return cur && cur.kind === "file" && cur.media === "text";
    }

    function updatePreview(item) {
        // Ya visible para este mismo item: no recargar (evita parpadeo).
        if (item && previewOk) {
            if ((item.kind === "clip" && item.isImage && item.cid === previewCid)
                || (item.kind === "file" && (item.media === "audio" || item.media === "video") && item.path === previewFile))
                return;
        }
        if (item && item.kind === "file" && item.media === "text" && item.path === previewFile && previewText !== "")
            return;
        previewOk = false;
        previewCid = "";
        previewPath = "";
        previewFile = "";
        previewText = "";
        if (!item)
            return;
        if (item.kind === "clip" && item.isImage) {
            previewCid = item.cid;
            previewPath = Services.ClipboardService.previewImage(item.cid);
        } else if (item.kind === "file" && (item.media === "audio" || item.media === "video")) {
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

        width: 900
        height: 640
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
                    case "emoji": return tr("launcher.ph_emoji", "Emojis y símbolos…");
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
                        // Rota de modo (como cambiar de provider en walker)
                        cycleMode(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Backspace:
                        // En modo sistema con query vacía: subir de sección.
                        if (launcher.activeMode === "system" && launcher.query === "") {
                            const parent = SystemMenuRegistry.sectionInfo(launcher.menuSection).parent;
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

            // Pestañas de modo (equivale a los prefijos de walker)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: launcher.modes
                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        property bool isActive: launcher.activeMode === modelData.id

                        Layout.fillWidth: true
                        height: 30
                        radius: 15
                        color: isActive ? Appearance.md3.secondary_container : "transparent"
                        border.width: isActive ? 0 : 1
                        border.color: Appearance.md3.outline_variant

                        StyledText {
                            anchors.centerIn: parent
                            text: (modelData.pfx !== "" ? modelData.pfx + " " : "") + launcher.modeLabel(modelData.id)
                            font.pixelSize: 12
                            color: parent.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.id === "todo") {
                                    launcher.forcedMode = "";
                                    searchField.text = "";
                                } else if (modelData.id === "system") {
                                    launcher.forcedMode = "";
                                    launcher.goSection("main");
                                } else {
                                    launcher.forcedMode = "";
                                    searchField.text = modelData.pfx;
                                }
                                searchField.forceActiveFocus();
                            }
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
                            onClicked: launcher.goSection(modelData.id)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

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
                        currentIndex: count > 0 ? 0 : -1
                        highlightMoveDuration: 100
                        keyNavigationEnabled: false
                        model: launcher.results

                        onCountChanged: {
                            if (count > 0 && currentIndex === -1)
                                currentIndex = 0;
                            // El reseteo del modelo no siempre emite currentIndexChanged
                            // (el índice puede conservar el valor) y el currentItem aún
                            // puede ser nulo: diferir para que existan los delegados.
                            Qt.callLater(() => launcher.updatePreview(resultList.currentItem ? resultList.currentItem.modelData : null));
                        }
                        onCurrentIndexChanged: launcher.updatePreview(currentItem ? currentItem.modelData : null)

                        delegate: Rectangle {
                            id: entryDelegate

                            required property var modelData
                            required property int index

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
                                        source: entryDelegate.modelData.appIcon || ""
                                        fallback: "image-missing"
                                        visible: (entryDelegate.modelData.appIcon || "") !== ""
                                    }
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: entryDelegate.modelData.iconName || "circle"
                                        size: 24
                                        color: Appearance.md3.primary
                                        visible: (entryDelegate.modelData.appIcon || "") === "" && (entryDelegate.modelData.ch || "") === ""
                                    }
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: entryDelegate.modelData.ch || ""
                                        font.pixelSize: 24
                                        visible: (entryDelegate.modelData.ch || "") !== ""
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: entryDelegate.modelData.title || ""
                                        font.pixelSize: 14
                                        color: Appearance.md3.on_surface
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: (entryDelegate.modelData.cat ? entryDelegate.modelData.cat + " · " : "") + (entryDelegate.modelData.sub || "")
                                        font.pixelSize: 12
                                        color: Appearance.md3.on_surface_variant
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
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

                // ---- preview lateral (como walker preview.xml) ----
                Rectangle {
                    Layout.preferredWidth: 380
                    Layout.fillHeight: true
                    radius: 20
                    color: Appearance.md3.surface_container_low

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        property var cur: resultList.currentItem ? resultList.currentItem.modelData : null

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
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 96
                            visible: parent.cur && ((parent.cur.imagePath || "") === "") && !(launcher.hasLivePreview(parent.cur) && launcher.previewOk) && !(launcher.hasTextPreview(parent.cur) && launcher.previewText !== "")

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
                    }
                }
            }

            // Barra de ayuda
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tr("launcher.footer", "Enter ejecutar · Tab cambia de modo · Supr borra item clipboard · Esc limpiar/cerrar")
                font.pixelSize: 11
                color: Appearance.md3.on_surface_variant
                opacity: 0.8
            }
        }
    }

    function cycleMode(dir) {
        const order = ["todo", "system", "files", "web", "emoji", "calc", "clip"];
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
