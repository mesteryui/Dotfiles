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

// Scope ligero: el IPC vive aquí para responder antes de cargar.
// La PanelWindow (1200+ líneas + warmup de .desktop) solo se instancia al
// abrir por primera vez y el LazyLoader la cachea entre aperturas; por eso
// listModel se nullea con el launcher cerrado (si no, el churn en
// background dispararía setModel sobre vistas ocultas).
Scope {
    id: scope

    property bool shown: false
    // Modo forzado por IPC ("" = según prefijo del texto)
    property string forcedMode: ""
    // Sección actual del menú de sistema (navegación estilo Omarchy)
    property string menuSection: "main"
    // Sección pedida por IPC antes de que exista el item (se aplica en onLoaded).
    property string _pendingSection: ""

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            scope.forcedMode = "";
            scope.shown = !scope.shown;
        }
        function openClipboard(): void {
            toggleMode("clip");
        }
        function openEmoji(): void {
            toggleMode("emoji");
        }
        function openSystem(): void {
            scope.menuSection = "main";
            toggleMode("system");
        }
        function openMenu(section: string): void {
            const target = section || "main";
            const w = loader.item;
            if (w && scope.shown && w.activeMode === "system" && scope.menuSection === target) {
                scope.shown = false;
                return;
            }
            scope.forcedMode = "system";
            scope.shown = true;
            // Igual que navegar con chips o teclear ">": el campo muestra el
            // carácter y la sección se refresca (al abrir ya lo pone
            // onOpened; si seguía abierto hay que ponerlo aquí).
            if (w)
                w.goSection(target);
            else
                scope._pendingSection = target;
        }
        // Recarga los menús personalizados sin recargar todo el shell:
        // `qs ipc call launcher reloadMenus` -> "menus=S+U rev=N [...]".
        // SystemMenuRegistry es singleton: no necesita el item.
        function reloadMenus(): string {
            return SystemMenuRegistry.reloadMenus();
        }
        // Toggle por menú: si ya está abierto en ese menú, cierra; si no, abre.
        function toggleMode(name: string): void {
            const m = name || "todo";
            const w = loader.item;
            if (w && scope.shown) {
                w.toggleModeImpl(m);
                return;
            }
            // Primera apertura (item aún inexistente): prepara el estado;
            // el inner lo aplica en Component.onCompleted.
            if (m === "system") {
                scope.forcedMode = "system";
                scope.menuSection = "main";
                scope.shown = true;
                scope._pendingSection = "main";
                return;
            }
            scope.forcedMode = (m === "todo") ? "" : m;
            scope.shown = true;
        }
    }

    LazyLoader {
        id: loader

        loading: scope.shown
        onItemChanged: {
            if (item && scope._pendingSection !== "") {
                item.goSection(scope._pendingSection);
                scope._pendingSection = "";
            }
        }

        component: PanelWindow {
            id: launcher


            visible: scope.shown

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"
            exclusiveZone: -1

            MouseArea {
                anchors.fill: parent
                onClicked: scope.shown = false
            }

            HyprlandFocusGrab {
                windows: [launcher]
                active: scope.shown
                onCleared: Qt.callLater(() => scope.shown = false)
            }

            WlrLayershell.keyboardFocus: scope.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay



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
                if (scope.forcedMode !== "")
                    return scope.forcedMode;
                return "todo";
            }

            // Query sin prefijo (inmediata: decide modo + alimenta calc/files,
            // que ya tienen su propio debounce interno).
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

            // Query con debounce para el filtrado costoso (results/appModel).
            // Sin esto, cada tecla reconstruía uniqueApps()+alphaSort()+fuzzy.
            // El modo sigue siendo inmediato; solo la lista espera ~90 ms.
            property string debouncedQuery: ""

            Timer {
                id: filterDebounce

                interval: 90
                onTriggered: launcher.debouncedQuery = launcher.query
            }

            onQueryChanged: {
                if (launcher.query === "") {
                    filterDebounce.stop();
                    launcher.debouncedQuery = "";
                } else {
                    filterDebounce.restart();
                }
            }

            // Generación del filtro: la ve ResultList para distinguir "nueva
            // búsqueda" (query/modo => ir arriba) de "refresco de datos"
            // (snapshot de fd, Supr en clip, rescan .desktop => conservar
            // selección y scroll). Solo cambia con el filtro efectivo.
            property int filterEpoch: 0

            onDebouncedQueryChanged: launcher.filterEpoch++

            // Setup de apertura (llamado al cambiar visible con el item ya
            // creado y en Component.onCompleted en la primera apertura, donde
            // onLauncherVisibleChanged no se dispara por venir ya visible).
            function onOpened(): void {
                scope.menuSection = scope.forcedMode === "system" ? scope.menuSection : "main";
                searchField.text = launcher.prefixOf(scope.forcedMode);
                // Sincroniza el filtro debounced en apertura (sin esperar 90 ms).
                filterDebounce.stop();
                launcher.debouncedQuery = launcher.query;
                launcher.refreshPins();
                launcher.refreshSortedBase();
                fileSearch.snapshot = [];
                preview.reset();
                // Cada apertura empieza en orden canónico (no congelado).
                launcher.frozenIds = [];
                // La selección vuelve al principio en cada apertura.
                resultList.resetView();
                // Cada apertura empieza escribiendo, no navegando.
                launcher.navResults = false;
                if (scope.forcedMode === "clip" || scope.forcedMode === "")
                    Services.ClipboardService.refresh();
                // Modelos live del menú de sistema (búsqueda global + badges "Actual",
                // más menús propios; no-op si aún no se descubrieron).
                SystemMenuRegistry.refreshAll();
                // Generador de emojis en background (no-op tras el primero):
                // el arranque del shell ya no espera/spawnea python.
                EmojiService.ensureLib();
                searchField.forceActiveFocus();
            }

            function onClosed(): void {
                scope.forcedMode = "";
                // Sin selecciones a medias al cerrar: el diferido no debe pintar
                // nada de una sesión ya cerrada.
                preview.reset();
            }

            // Implementación del IPC toggleMode (la firma IPC vive en el scope y
            // reenvía aquí cuando el item ya existe).
            function toggleModeImpl(m: string): void {
                const cur = scope.forcedMode !== "" ? scope.forcedMode : launcher.activeMode;
                if (scope.shown && cur === m) {
                    scope.shown = false;
                    return;
                }
                if (m === "system") {
                    scope.forcedMode = "system";
                    scope.shown = true;
                    launcher.goSection("main");
                    return;
                }
                scope.forcedMode = (m === "todo") ? "" : m;
                scope.shown = true;
                // Al abrir ya lo pone onOpened; si seguía abierto hay que ponerlo
                // aquí (si no, el prefijo viejo seguiría mandando sobre el modo).
                searchField.text = launcher.prefixOf(scope.forcedMode);
                searchField.forceActiveFocus();
            }

            // Sincronía scope<->item: el estado vive en el scope; el item
            // reacciona a sus cambios y corre el setup en la primera carga
            // (donde no hay cambio que observar).
            Connections {
                target: scope

                function onShownChanged() {
                    if (scope.shown)
                        launcher.onOpened();
                    else
                        launcher.onClosed();
                }
            }

            Component.onCompleted: {
                launcher.refreshPins();
                launcher.refreshSortedBase();
                launcher.debouncedQuery = launcher.query;
                if (scope.shown)
                    launcher.onOpened();
            }

            // Cachés reactivas: pins (Persistent) y base ordenada (.desktop).
            // Evitan reconstruir+ordenar en cada tecla; el filtro solo reordena.
            Connections {
                target: Persistent.persistence

                function onPinnedAppsChanged() {
                    launcher.refreshPins();
                }
            }

            Connections {
                target: Persistent

                function onReadyChanged() {
                    if (Persistent.ready)
                        launcher.refreshPins();
                }
            }

            Connections {
                target: DesktopEntries.applications

                function onValuesChanged() {
                    launcher.refreshSortedBase();
                }
            }

            // Entrar a una sección (click, breadcrumb, IPC): refresca si es dinámica
            // (interna o propia; no-op en el resto).
            function goSection(id) {
                scope.menuSection = id;
                searchField.text = ">";
                // Nueva sección = nuevo listado: ir arriba (ver filterEpoch).
                launcher.filterEpoch++;
                SystemMenuRegistry.refreshSection(id);
                searchField.forceActiveFocus();
            }

            // Mueve la selección: vive en ResultList (con el flash de borde).

            // Al entrar a modo clipboard refresca historial.
            // Además sincroniza el filtro debounced (cambio de modo = instantáneo).
            onActiveModeChanged: {
                filterDebounce.stop();
                launcher.debouncedQuery = launcher.query;
                launcher.filterEpoch++;
                if (scope.shown && activeMode === "clip")
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
                // Lectura fresca por índice (no currentData cacheado): el
                // contenido puede haber cambiado sin moverse el índice.
                const item = resultList.itemAt(resultList.currentIndex);
                if (!item)
                    return;
                activateItem(item);
            }

            function activateItem(it) {
                // Sin item (lista vacía, índice -1, swap de modelo en curso):
                // no-op sin excepción (antes `it.kind` lanzaba TypeError).
                if (!it)
                    return;
                // Snapshot de app .desktop (modo todo con appModel): no trae
                // `kind`, se detecta por la marca isDesktopApp. Se ejecuta el
                // entry vivo (no el snapshot) para no tocar QObjects que un
                // rescan de .desktop ya haya podido destruir.
                if (it.isDesktopApp === true) {
                    const live = launcher.liveEntryFor(it.id);
                    const runInTerm = live ? live.runInTerminal : it.runInTerminal;
                    // Normaliza a Array JS real: DesktopEntry.command puede
                    // llegar como array-like (sin .concat de Array).
                    const rawCmd = live ? live.command : it.command;
                    const cmd = [];
                    if (rawCmd && typeof rawCmd.length === "number") {
                        for (let c = 0; c < rawCmd.length; c++)
                            cmd.push(String(rawCmd[c]));
                    }
                    const workDir = live ? live.workingDirectory : it.workingDirectory;
                    if (runInTerm && cmd.length > 0) {
                        Quickshell.execDetached({
                            command: ["xdg-terminal-exec", "-e"].concat(cmd),
                            workingDirectory: workDir
                        });
                    } else if (live) {
                        live.execute();
                    } else if (cmd.length > 0) {
                        Quickshell.execDetached(cmd);
                    } else if (it.execString) {
                        launcher.runShell(it.execString);
                    } else {
                        return;
                    }
                    scope.shown = false;
                    return;
                }
                // Navegación entre secciones: no cierra el menú.
                if (it.kind === "menuback" || (it.kind === "system" && it.isSubmenu)) {
                    launcher.goSection(it.section);
                    return;
                }
                switch (it.kind) {
                case "system":
                    // Entrada vacía o submenú sin shell: no-op (no cerrar).
                    if (!it.shell)
                        return;
                    launcher.runShell(it.shell);
                    break;
                case "emoji":
                    if (!it.ch)
                        return;
                    EmojiService.copy(it.ch);
                    break;
                case "clip":
                    if (!it.cid)
                        return;
                    Services.ClipboardService.copyEntry(it.cid, it.isImage);
                    break;
                case "file":
                    if (!it.path)
                        return;
                    launcher.openPath(it.path);
                    break;
                case "calc":
                    // Placeholder ("Escribe una operación", "Calculando…") o
                    // resultado vacío: no-op (no limpiar el clipboard).
                    if (!it.result)
                        return;
                    Services.ClipboardService.copyText(it.result);
                    break;
                case "web":
                    // Placeholder ("Escribe para buscar"): no-op.
                    if (!it.url)
                        return;
                    launcher.runCmd(["xdg-open", it.url]);
                    break;
                default:
                    // Kind desconocido (no debería pasar): no cerrar.
                    return;
                }
                scope.shown = false;
            }

            // ---------- calculadora (estado + qalc en LauncherCalc) ----------
            LauncherCalc {
                id: calcState

                query: launcher.query
                active: scope.shown && launcher.activeMode === "calc"
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
                active: scope.shown && launcher.activeMode === "files"
            }

            property var results: {
                // lang: reevaluar al cambiar el idioma (los items llevan textos traducidos)
                const lang = Services.I18nService.language;
                const q = launcher.debouncedQuery;
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
            // IDs persistidos en persistence.json. Se cachean en cachedPins
            // para no recorrer el adapter en cada evaluación del filtro
            // (antes pinnedIds() se llamaba por cada tecla).
            property var cachedPins: []

            function refreshPins() {
                if (!Persistent.ready) {
                    launcher.cachedPins = [];
                    return;
                }
                // Ojo: list<string> llega como objeto array-like (isArray false),
                // no como Array JS: se copia a mano en vez de filtrar directo.
                const v = Persistent.persistence.pinnedApps;
                const out = [];
                if (v && typeof v.length === "number") {
                    for (let i = 0; i < v.length; i++)
                        if (typeof v[i] === "string" && v[i] !== "")
                            out.push(v[i]);
                }
                launcher.cachedPins = out;
            }

            function pinnedIds() {
                return launcher.cachedPins;
            }

            function isPinned(entryId) {
                return launcher.pinnedIds().indexOf(entryId) >= 0;
            }

            function togglePinCurrent() {
                if (launcher.activeMode !== "todo" || !Persistent.ready)
                    return;
                const d = resultList.itemAt(resultList.currentIndex);
                if (!d || d.isDesktopApp !== true || !d.id)
                    return;
                const pins = launcher.pinnedIds().slice();
                const i = pins.indexOf(d.id);
                if (i >= 0) {
                    pins.splice(i, 1);
                    // Congela el orden visible actual para no saltar.
                    // values puede ser array-like (sin .map): copia a mano.
                    const vals = appModel.values;
                    const ids = [];
                    if (vals && typeof vals.length === "number") {
                        for (let k = 0; k < vals.length; k++)
                            if (vals[k] && vals[k].id)
                                ids.push(vals[k].id);
                    }
                    launcher.frozenIds = ids;
                } else {
                    pins.push(d.id);
                    launcher.frozenIds = [];
                }
                Persistent.persistence.pinnedApps = pins;
            }

            // Ranking unificado (FuzzyMatch por niveles + pesos):
            // nombre 1.0 > comentario 0.25 > id 0.2. El motor ya prioriza
            // exacto > prefijo > prefijo-palabra > substring > fuzzy > typo,
            // así que no hace falta la cascada excluyente de antes (que
            // ocultaba buenos fuzzy cuando había un contains). Los pesos son
            // agresivos a propósito: un substring en el comentario no debe
            // ganar a un fuzzy en el nombre ("stem" -> Steam, no "sistema").
            function todoFilter(q, apps) {
                return Services.FuzzySearch.filterItemsMulti(q, apps, e => [{ text: e.name, weight: 1 }, { text: e.comment || "", weight: 0.25 }, { text: e.id || "", weight: 0.2 }]).slice(0, 30);
            }

            // Orden visual congelado al desfijar: la app se queda donde está y
            // la lista no salta hasta que se haga una búsqueda, se cambie de
            // modo, se reabra o se fije otra. Guarda IDs en orden visible.
            property var frozenIds: []

            // Base ordenada cacheada: dedup+sort solo cambian con .desktop.
            // Antes se reconstruía por cada tecla dentro de appModel.values.
            property var sortedBase: []

            function refreshSortedBase() {
                // Snapshots planos (ver snapshotEntry en LauncherApps.js):
                // nunca se guardan QObjects vivos de DesktopEntries en el
                // modelo (un rescan los destruye y el DelegateModel acabaría
                // leyendo memoria muerta -> SIGSEGV al teclear).
                const base = LauncherApps.uniqueApps([...DesktopEntries.applications.values]);
                launcher.sortedBase = LauncherApps.alphaSort(base.map(e => LauncherApps.snapshotEntry(e)));
            }

            // Entry vivo para ejecutar: el modelo solo guarda snapshots; la
            // ejecución usa el objeto actual (puede haber cambiado con un
            // rescan de .desktop desde que se filtró la lista).
            function liveEntryFor(id) {
                const vals = DesktopEntries.applications.values;
                for (let i = 0; i < vals.length; i++)
                    if (vals[i] && vals[i].id === id)
                        return vals[i];
                return null;
            }

            // ---------- aplicaciones (modo todo) ----------
            // Fuente única y viva: sortedBase -> fijadas primero -> filtro.
            // ScriptModel re-suscribe el binding ante altas/bajas de .desktop y
            // actualiza solo los delegates que cambian, sin snapshots ni contadores.
            // Los valores son snapshots planos (ver snapshotEntry): identidad
            // estable por id y sin QObjects vivos que un rescan destruya bajo
            // los pies del DelegateModel; el delegate los pinta directo y la
            // ejecución resuelve el entry vivo por id (liveEntryFor).
            // El filtro lee debouncedQuery: no se recalcula por cada tecla.
            ScriptModel {
                id: appModel

                values: {
                    const base = launcher.sortedBase;
                    const pins = launcher.cachedPins;
                    const q = launcher.debouncedQuery;
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
                    return sectionItems(scope.menuSection);
                // Pesos: título 1.0 > subtítulo 0.25 > sección 0.1 (el nombre manda).
                return Services.FuzzySearch.filterItemsMulti(q, systemPool(), it => [{ text: it.title, weight: 1 }, { text: it.sub, weight: 0.25 }, { text: it.cat, weight: 0.1 }]);
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
                const d = resultList.itemAt(resultList.currentIndex);
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
                // Título 1.0 + texto completo (acotado) 0.25: encuentra contenido
                // más allá de los 90 caracteres visibles del título.
                return Services.FuzzySearch.filterItemsMulti(q, out, it => [{ text: it.title, weight: 1 }, { text: (it.fullText || "").slice(0, 200), weight: 0.25 }]);
            }

            // Resultados de archivos: mapeo (FileMenu) + fuzzy. El orden base
            // ya viene ordenado del snapshot (ver LauncherFileSearch).
            function fileResultsList(q) {
                const cat = tr("launcher.category_file", "Archivo");
                const out = FileMenu.mapSnapshot(fileSearch.snapshot, cat);
                if (q === "")
                    return out;
                // Nombre 1.0 > ruta 0.25. nameFirst conserva el boost extra de
                // prefijo-de-nombre (ya rankeado primero por el motor).
                const matches = Services.FuzzySearch.filterItemsMulti(q, out, it => [{ text: it.title, weight: 1 }, { text: it.sub, weight: 0.25 }]);
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
                            if (scope.forcedMode !== "" && !text.startsWith(launcher.prefixOf(scope.forcedMode)))
                                scope.forcedMode = "";
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
                                scope.shown = false;
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
                                    const parent = SystemMenuRegistry.sectionInfo(scope.menuSection).parentId;
                                    if (parent !== "") {
                                        launcher.goSection(parent);
                                        event.accepted = true;
                                    }
                                }
                                break;
                            case Qt.Key_Delete:
                                if (launcher.activeMode === "clip") {
                                    const d = resultList.itemAt(resultList.currentIndex);
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
                                                scope.forcedMode = "";
                                                searchField.text = "";
                                            } else if (modelData.modeId === "system") {
                                                scope.forcedMode = "";
                                                launcher.goSection("main");
                                            } else {
                                                scope.forcedMode = "";
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

                            model: SystemMenuRegistry.trail(scope.menuSection)

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
                                // Modelo nulo con el launcher cerrado: la ventana
                                // se cachea entre aperturas (LazyLoader) y si las
                                // vistas quedaran suscritas, cualquier cambio en
                                // background (DesktopEntries, clipboard, menús)
                                // dispararía setModel sobre vistas ocultas -> el
                                // mismo SIGSEGV que con el toggle por IPC.
                                // Modo todo: ScriptModel vivo de DesktopEntries.
                                // Resto de modos: array plano de `results`.
                                listModel: !scope.shown ? null : (launcher.activeMode === "todo" ? appModel : launcher.results)
                                activeMode: launcher.activeMode
                                // Generación del filtro (ver filterEpoch): distingue
                                // nueva búsqueda (ir arriba) de refresco de datos
                                // (conservar selección y scroll).
                                filterEpoch: launcher.filterEpoch
                                isPinnedFn: appId => launcher.isPinned(appId)
                                onActivated: item => launcher.activateItem(item)
                                onHighlighted: item => {
                                    // Vecinos para el prefetch ANTES de programar:
                                    // sin item (hueco de swap) no hay vecinos.
                                    preview.neighbors = item ? resultList.neighborItems() : [];
                                    preview.schedule();
                                }
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
                            previewError: preview.previewError
                            metaText: preview.metaText
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
                    scope.forcedMode = "";
                    launcher.goSection("main");
                    return;
                }
                const p = launcher.prefixOf(order[i]);
                scope.forcedMode = "";
                searchField.text = p;
                if (order[i] === "clip")
                    Services.ClipboardService.refresh();
            }
        }
    }
}
