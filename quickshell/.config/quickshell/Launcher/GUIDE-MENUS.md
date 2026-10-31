# Launcher — menu authoring (English guide)

Full guide (Spanish): `GUIA-MENUS.md`. Short map: `README.md`.
This file is the English contract summary.

Modes (prefix → logic, see `Base/MenuModes.js` `defs()`): empty `todo`
(installed apps only, live `DesktopEntries` model + `Base/
LauncherApps.js` ordering), `>` system (`MenuProviders/System/` +
`MenuProviders/*.qml`, static or `refresh()`), `/` files (`fd` in
`$HOME`, `Modes/LauncherFileSearch.qml` 250 ms debounce + `Modes/
FileMenu.js` `fdCommand`), `@` web (DuckDuckGo / direct URL,
`AppLauncher.webResults()`), `.` emoji (runtime catalog via
`EmojiService.qml` + `scripts/emoji-dump.py`, groups + recents/
favorites, Enter copies via `wl-copy`), `=` calc (`qalc`, `Modes/
LauncherCalc.qml` 250 ms debounce + `Base/CalcCache.js`
stale-while-revalidate), `:` clipboard (`cliphist` via
`ClipboardService`, preview always). Emoji uses a grid view
(`viewFor()`); the rest use a list. Window is 600 px, 900 px with
the preview panel.

Pieces: `AppLauncher.qml` (~1050 lines: window + IPC + mode dispatch
`typedMode`/`activeMode`/`query`/`debouncedQuery` + `results` +
`activateItem` + `modeLabel`/`modeShape`/`modeIcon` helpers), `UI/`
(`LauncherSearchBar.qml` with `controller`/`scopeObj`/`resultView`,
`LauncherModeBar.qml` with `pickTodo`/`pickSystem`/`pickMode` signals,
`ResultList.qml`, `PreviewPanel.qml`), `LauncherPreview.qml`
(120 ms deferred preview), `Modes/`, `Base/` (`MenuModes.js`,
`ItemKinds.js`, `LauncherApps.js`, `ShellUtils.js` with
`shellEscape`/`fileUrl`, `CalcCache.js`), `MenuStore.qml`
(discovers `MenuProviders/System/*.qml` + `MenuProviders/*.qml`,
`checkNow()` reloads on open only if files changed),
`SystemMenuRegistry.qml` (read facade: `sections`,
`sectionResultItems`, `systemSearchPool`, `trail`, `refreshSection/
refreshAll/reloadMenus`, `toResultItem`, `shellOf`),
`MenuDefinition.qml`, `MenuProviders/` (10 built-ins: `main`,
`screenshot`, `configure`, `appearance`, `packages`, `setup`,
`games` static + `powerprofiles`, `fastfetch`, `animations`
dynamic), `EmojiService.qml`, `FilePreviewService.qml`.

Custom menu contract (`MenuDefinition`, do NOT redeclare with
`property`): provide `sectionId` (lowercase-dashes, unique),
`titleFallback` (+ `titleKey` for i18n, see `Core/i18n/I18N.md`),
`icon` (valid Material Symbol), `parentId` (default `"main"`),
`entries` built with `shell()`/`ipc()`/`submenu()`/`entry()` (all
take `opts` `{titleKey, subtitleKey, preview}`); dynamic menus
implement `refresh()` reassigning `entries` wholesale and put
workers in `helpers`. Scaffold with
`MenuProviders/new-menu.sh Name "Title" [parentId] [icon]`
(reserved: `main,todo,system,files,web,emoji,calc,clip,
powerprofiles,fastfetch,animations`); applies on next open, or
reload live with `qs ipc call launcher reloadMenus`.

IPC (`qs ipc call launcher …`): `toggle`, `toggleMode(name)`,
`openClipboard`, `openEmoji`, `openSystem`, `openMenu(section)`,
`reloadMenus`.
