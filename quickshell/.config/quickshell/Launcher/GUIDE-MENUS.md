# Launcher — menu authoring (English guide)

Full guide (Spanish): `GUIA-MENUS.md`. Short map: `README.md`.
This file is the English contract summary.

Modes (prefix → logic): empty (everything: apps + calc + system +
web shortcut), `>` system (`MenuProviders/System/` +
`MenuProviders/*.qml`, static or `refresh()`), `/` files (`fd` in
`$HOME`, see `Modes/LauncherFileSearch.qml` + `Modes/FileMenu.js`),
`@` web (DuckDuckGo), `.` emoji (`EmojiService.qml`, groups,
recent/favorites, Enter copies via `wl-copy`), `=` calc (`qalc`,
see `Modes/LauncherCalc.qml`), `:` clipboard (`cliphist`).

Pieces: `AppLauncher.qml` (window + IPC + results dispatch), `UI/`
(`ResultList.qml`, `PreviewPanel.qml`), `Modes/`, `Base/` (`MenuModes.js`,
`CalcCache.js`, `LauncherApps.js`), `MenuStore.qml`,
`SystemMenuRegistry.qml`, `MenuDefinition.qml`, `MenuProviders/`.

Custom menu contract (`MenuDefinition`): provide `sectionId`, `title`
(+ `titleKey` for i18n, see `Core/i18n/I18N.md`), items with
`{kind:"system", title, sub, iconName, shell}` or `isSubmenu` +
`section`. Static menus list items; dynamic ones implement `refresh()`.
Register via `MenuProviders/new-menu.sh`, reload live with
`qs ipc call launcher reloadMenus`.

IPC (`qs ipc call launcher …`): `toggle`, `toggleMode(name)`,
`openClipboard`, `openEmoji`, `openSystem`, `openMenu(section)`,
`reloadMenus`.
