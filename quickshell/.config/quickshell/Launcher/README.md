# Launcher — menú unificado

Un solo menú con 7 modos por prefijo. Este README es el mapa;
para crear menús del modo `>` ver `GUIA-MENUS.md`.

## Modos

| id | prefijo | qué busca | lógica en |
|---|---|---|---|
| `todo` | (nada) | apps (.desktop) + fijadas | `AppLauncher` + `Base/LauncherApps.js` |
| `system` | `>` | menús `MenuProviders/` | `SystemMenuRegistry` ← `MenuStore` |
| `files` | `/` | `fd` en `$HOME` | `Modes/LauncherFileSearch.qml` + `Modes/FileMenu.js` |
| `web` | `@` | DuckDuckGo / URL directa | `AppLauncher.webResults()` |
| `emoji` | `.` | catálogo runtime + recientes/favoritos | `EmojiService.qml` (+ `scripts/emoji-dump.py`) |
| `calc` | `=` | `qalc`, Enter copia | `Modes/LauncherCalc.qml` |
| `clip` | `:` | historial `cliphist` (+imágenes) | `Core/Services/ClipboardService` |

## Flujo de datos

```
tecla → searchField.text → typedMode/activeMode → query (sin prefijo)
  → results(q) por modo  (todo usa appModel vivo de DesktopEntries)
  → UI/ResultList (navegación + flash) → activateItem(item)
  → preview diferido (~120 ms) vía LauncherPreview → UI/PreviewPanel
```

Estado: `AppLauncher` guarda lo efímero (`launcherVisible`,
`forcedMode`, `menuSection`, `query`); cada componente guarda lo suyo
(`calcState`, `fileSearch`, `preview`). Los servicios guardan lo
persistente (pins en `Persistent`, recientes/favoritos de emoji en
`~/.local/state/quickshell/emoji.json`).

## Piezas y quién hace qué

* `AppLauncher.qml` — ventana, IPC, modos, dispatch de `results` y
  activación. La UI vive en `UI/LauncherSearchBar.qml` (campo + atajos,
  expone `field`; `controller`/`scopeObj`/`resultView`) y
  `UI/LauncherModeBar.qml` (chips, grupos emoji, breadcrumb; escribe el
  campo vía `pickTodo`/`pickSystem`/`pickMode`).
* `LauncherPreview.qml` — orquesta el preview (clip siempre;
  files/system solo con imagen o texto). `UI/PreviewPanel.qml` solo pinta.
* `MenuStore.qml` — **descubre** menús: escanea `MenuProviders/`,
  instancia cada `MenuDefinition` y guarda providers + `revision`.
* `SystemMenuRegistry.qml` — **fachada de lectura**: secciones,
  búsqueda global (`systemSearchPool`), trail/breadcrumbs. No descubre nada.
* `MenuDefinition.qml` — componente base que hereda cada provider
  (`sectionId`, `entries`, `refresh()`, fábricas `shell/ipc/submenu/entry`).
* `Base/` — lógica pura sin estado: `MenuModes.js` (tabla de modos),
  `ItemKinds.js` (predicados `isClipText…`), `LauncherApps.js`
  (orden/dedup .desktop), `ShellUtils.js` (`shellEscape`/`fileUrl`,
  única implementación salvo la copia documentada en `Modes/FileMenu.js`).
* `UI/` — `ResultList.qml`, `PreviewPanel.qml`, `LauncherSearchBar.qml`,
  `LauncherModeBar.qml`. No conocen modos ni servicios (salvo
  `ItemKinds`/`MenuModes` para el preview); ven el launcher solo vía
  `controller`/`scopeObj`.
* `Modes/` — un modo = su lógica con `query/active` de entrada y
  `snapshot`/`result` de salida (ver `LauncherCalc` como ejemplo mínimo).

## IPC (`qs ipc call launcher …`)

`toggle`, `toggleMode <todo|system|files|web|emoji|calc|clip>`,
`openClipboard`, `openEmoji`, `openSystem`, `openMenu <sección>`,
`reloadMenus` (re-escanea providers sin reiniciar el shell).

## Añadir un modo

1. Prefijo + entrada en `Base/MenuModes.js` (`defs()`).
2. Fuente de resultados (nuevo `Modes/MiModo.qml` con `query/active`,
   o función `xxxResults(q)` en `AppLauncher` si es trivial).
3. Rama en `results`, caso en `activateItem()`, chip (usa `modeShape`/
   `modeIcon`), placeholder y fila en `modeLabel()`.
4. Preview solo si hace falta (`MenuModes.needsPreview` + `LauncherPreview.update`).

## Añadir un menú del modo `>`

`./MenuProviders/new-menu.sh MiMenu "Mi menú"` y edita el fichero
(detalles en `GUIA-MENUS.md`). Sin tocar Registry ni Store.

## Log

`console.debug/info/warn/error(...)` directo en el código. Sin niveles ni wrapper.
