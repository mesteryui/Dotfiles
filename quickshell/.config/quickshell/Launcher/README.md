# Launcher — menú unificado

Un solo menú con 7 modos por prefijo (`MenuModes.js`). Este README es
el mapa; para crear menús del modo `>` ver `GUIA-MENUS.md`.

## Modos

| id | prefijo | vista | preview | qué busca | lógica en |
|---|---|---|---|---|---|
| `todo` | (nada) | lista | nunca | apps (.desktop, modelo vivo) | `AppLauncher` + `Base/LauncherApps.js` |
| `system` | `>` | lista | condicional (item con imagen) | menús `MenuProviders/` | `SystemMenuRegistry` ← `MenuStore` |
| `files` | `/` | lista | condicional (imagen/texto/pdf/audio/video) | `fd` en `$HOME` | `Modes/LauncherFileSearch.qml` (debounce 250 ms + watchdog 15 s) + `Modes/FileMenu.js` (`fdCommand`) |
| `web` | `@` | lista | nunca | DuckDuckGo / URL directa | `AppLauncher.webResults()` |
| `emoji` | `.` | grid | nunca | catálogo runtime + recientes/favoritos | `EmojiService.qml` (+ `scripts/emoji-dump.py`) |
| `calc` | `=` | lista | nunca | `qalc`, Enter copia | `Modes/LauncherCalc.qml` (debounce 250 ms, watchdog 5 s, caché negativa 30 s) + `Base/CalcCache.js` |
| `clip` | `:` | lista | siempre | historial `cliphist` (+imágenes) | `Core/Services/ClipboardService` |

Ancho: 600 px, 900 px con preview (`PreviewPanel`: 380 + 340/96
según contenido).

## Flujo de datos

```
tecla → searchField.text → typedMode/activeMode → query (sin prefijo)
  → debouncedQuery (90 ms; cambio de modo = instantáneo)
  → results(q) por modo  (todo usa appModel vivo de DesktopEntries)
  → UI/ResultList (navegación + flash) → activateItem(item)
  → preview diferido (~120 ms) vía LauncherPreview → UI/PreviewPanel
```

Estado: el `Scope` guarda lo efímero (`shown`, `forcedMode`,
`menuSection`, `query`, `_pendingSection`); el `PanelWindow` interior
(`AppLauncher.qml`, ~1050 líneas) guarda `activeMode`, `results`,
`debouncedQuery`, `calcState`, `fileSearch`, preview. Los servicios
guardan lo persistente (pins en `Persistent`, recientes/favoritos de
emoji en `~/.local/state/quickshell/emoji.json` con debounce).

## Piezas y quién hace qué

* `AppLauncher.qml` — ventana (`600/900x640`, clic-fuera cierra,
  `HyprlandFocusGrab` + `WlrLayershell`), IPC, `GlobalShortcut`
  (`quickshell:launcher`), modos (`typedMode`,
  `activeMode`, `query`, `goSection`, `toggleModeImpl`), dispatch de
  `results` (`todo/system/emoji/clip/file/calc/webResults`) y
  `activateItem` (`app`→`entry.execute()`; `system`→submenú navega,
  hoja ejecuta `sh -c`/`qs ipc`; `emoji`/`calc`→`wl-copy`;
  `clip`→`ClipboardService`; `file`/`web`→`xdg-open`). Helpers de
  modo: `modeLabel`, `modeShape`, `modeIcon`, `prefixOf`, `tr`.
* `DesktopEntryRefresh.qml` — al abrir, compara una huella
  (`find` con path+mtime+ctime+tamaño) de los `.desktop`; solo si
  cambió fuerza el rescan de Quickshell (marcador no-`.desktop` en
  `~/.local/share/applications`). Sin watchers por fichero: coste
  cero con el launcher cerrado. `AppLauncher` rehace `sortedBase`
  desde `DesktopEntries.applicationsChanged`.
* `UI/LauncherSearchBar.qml` — campo + atajos; expone `field`;
  props `controller`/`scopeObj`/`resultView`. `cycleMode`,
  `Ctrl+J/N`/`Ctrl+K/P`, `Tab` rota modo, `Backspace` en sistema
  vacío sube de sección, `Supr` en clip borra, `Ctrl+Mayús+F`
  favorito en emoji.
* `UI/LauncherModeBar.qml` — chips de modo, grupos emoji, breadcrumb;
  escribe el campo vía señales `pickTodo`/`pickSystem`/`pickMode`.
* `UI/ResultList.qml` — lista/grid (`isGrid` si
  `MenuModes.viewFor(mode)==="grid"`), navegación, flash de borde.
* `UI/PreviewPanel.qml` — solo pinta (`hasPreview` =
  `MenuModes.needsPreview`; 380 px + contenido).
* `LauncherPreview.qml` — orquesta el preview (clip siempre;
  files/system condicional; debounce 120 ms; `FilePreviewService`
  para audio/video/pdf/texto, `ClipboardService.previewImage`).
* `MenuStore.qml` — **descubre** menús: lista `MenuProviders/System/
  *.qml` + `MenuProviders/*.qml` vía `sh`, `Qt.createComponent`,
  instancia y guarda `providers` (internos primero) + firma de
  ficheros (`checkNow()` al abrir recarga solo si cambiaron;
  `reload()` fuerza).
* `SystemMenuRegistry.qml` — **fachada de lectura**: `sections()`,
  `sectionInfo()`, `trail()`, `staticEntries()`,
  `sectionResultItems()` (navegar), `systemSearchPool()` (buscar),
  `refreshSection()`/`refreshAll()`/`reloadMenus()`, `toResultItem()`,
  `shellOf()`. No descubre nada.
* `MenuDefinition.qml` — base de cada provider (`sectionId`,
  `titleFallback`, `titleKey`, `icon`, `parentId`, `entries`,
  `helpers`, `refresh()`; NO redeclare con `property` al heredar).
  Fábricas `shell()`/`ipc()`/`submenu()`/`entry()` (+ `shellCmd()`/
  `ipcCall()`), todas con `opts` `{titleKey, subtitleKey, preview}`.
* `Base/` — lógica pura: `MenuModes.js` (tabla 7 modos,
  `prefixOf`/`modeForPrefix`/`supportsPreview`/`needsPreview`/
  `viewFor`), `ItemKinds.js` (predicados clip/imagen/texto…),
  `LauncherApps.js` (orden/dedup .desktop), `ShellUtils.js`
  (`shellEscape`/`fileUrl`, única implementación),
  `CalcCache.js` (stale-while-revalidate para calc, `.pragma library`
  para no crear binding loop).
* `Modes/` — `LauncherCalc.qml`, `LauncherFileSearch.qml`,
  `FileMenu.js` (mapeo/orden + `fdCommand`).
* `MenuProviders/System/` — 10 internos (7 estáticos: `main`,
  `screenshot`, `configure`, `appearance`, `packages`, `setup`,
  `games`; 3 dinámicos con `refresh()`: `powerprofiles`,
  `fastfetch`, `animations`). Tus menús van en `MenuProviders/*.qml`.
* `EmojiService.qml` — catálogo runtime (`Launcher/scripts/
  emoji-dump.py --all`, TSV vía `Process`+`SplitParser`), grupos,
  Recientes/Favoritos (TTL 30 días), `queryItems()`, `copy()`,
  `sourceInfo()`; `EmojiCustom.js` = tus emojis (prioridad máxima).
  Watchdog de 60 s al dump de Python: si se cuelga cae al camino de
  error ya existente.
* `FilePreviewService.qml` — miniaturas: audio carátula `ffmpeg`
  512 px, video `ffmpegthumbnailer` 384 px, pdf `pdftoppm` 72 dpi,
  texto `head -c 6000` (tope 204800 = `QSTEXT_TOO_BIG`); caché
  `/tmp/qs-filepreview/` tope 60; `request()`/`requestText()`/
  `requestMeta()`, señales `ready`/`textReady`, solo gana la última.
  Watchdogs (30 s cover/meta, 15 s texto) matan extractores colgados;
  el `onExited` sirve vacío como cualquier otro fallo.

## IPC (`qs ipc call launcher …`)

`toggle`, `toggleMode <todo|system|files|web|emoji|calc|clip>`,
`openClipboard`, `openEmoji`, `openSystem`, `openMenu <sección>`,
`reloadMenus` (re-escanea providers, devuelve `"menus=… rev=…"`).

## Atajo global (`GlobalShortcut`)

`AppLauncher.qml` registra un `GlobalShortcut` en el `Scope` (no en la
`PanelWindow`): vive fuera del `LazyLoader`, así que responde desde el
arranque sin instanciar la ventana.

| id | descripción | acción |
|---|---|---|
| `quickshell:launcher` | Toggle the launcher | mismo toggle que el IPC (`scope.toggleLauncher()`): abre en modo `todo` o cierra |

Se liga en la config de Hyprland con el dispatcher `global`:

```lua
hl.bind("ALT + SPACE", hl.dsp.global("quickshell:launcher"),
	{ description = "Apps: Abrir menu" })
```

(`hyprctl globalshortcuts` lista los atajos registrados.) El protocolo
nativo de Hyprland (`hyprland_global_shortcuts_v1`) no necesita
xdg-desktop-portal. Ojo: `appid:name` no puede repetirse entre
instancias de quickshell.

## Añadir un modo

1. Prefijo + entrada en `Base/MenuModes.js` (`defs()`).
2. Fuente de resultados (nuevo `Modes/MiModo.qml` con `query/active`,
   o función `xxxResults(q)` en `AppLauncher` si es trivial).
3. Rama en `results`, caso en `activateItem()`, chip (usa `modeShape`/
   `modeIcon`), placeholder y fila en `modeLabel()`.
4. Preview solo si hace falta (`MenuModes.needsPreview` + `LauncherPreview`).

## Añadir un menú del modo `>`

`./MenuProviders/new-menu.sh MiMenu "Mi menú" [parentId] [icono]` y
edita el fichero (detalles en `GUIA-MENUS.md`). `sectionId` en
minúsculas-guiones; reservados: `main,todo,system,files,web,emoji,
calc,clip,powerprofiles,fastfetch,animations`. Sin tocar Registry
ni Store. Se aplica al abrir el launcher (o `reloadMenus`).

## Log

`console.debug/info/warn/error(...)` directo en el código. Sin niveles ni wrapper.
