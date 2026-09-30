# Features

- `CheatSheet/` — keybind cheatsheet (`Scope` + `LazyLoader` +
  `CheatsheetSheet`: search, grid, filtering, keyboard nav; cards
  `CheatsheetCategoryCard`, rows `CheatsheetKeybindRow`).
- `Notifications/` — center, history cards (`NotificationHistoryCard`
  uses `M3SelectionFill` + `M3StateLayer`), toasts.
- `OSD/` — on-screen displays (volume, brightness, media, capslock).
- `WindowSwitcher/` — alt-tab switcher.

All heavy features follow the `shell.qml` pattern: light `Scope` with
IPC/shortcuts at startup, `PanelWindow` instantiated lazily on open.
