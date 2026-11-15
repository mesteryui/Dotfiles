# Features

- `CheatSheet/` (5 files) — keybind cheatsheet. `Cheatsheet.qml`
  (light `Scope`: IPC `cheatsheet` `toggle`/`show`/`hide` +
  autohide + internal `LazyLoader` fullscreen `PanelWindow`) +
  `CheatsheetSheet.qml` (two-pane menu: category tabs on the left,
  selected category's binds on the right; search via `FuzzySearch`,
  `filteredCategories`, keyboard nav `moveSelection`/`moveCategory`,
  scroll helpers) + tabs `CheatsheetCategoryTab` + rows
  `CheatsheetKeybindRow` + chips `CheatsheetKeyChip`.
- `Notifications/` (5 files) — `Notifications.qml` (light `Scope`:
  `LazyLoader` loads the heavy `NotificationCenter` on open and destroys
  it on close; popups stay direct per screen) + `NotificationCenter.qml`
  (reads `NotificationData.history`, visibility via
  `NotificationService.centerOpen`) + `NotificationHistoryCard.qml`
  (`M3SelectionFill` + `M3StateLayer`) + `NotificationPopups.qml` +
  `NotificationToastCard.qml`.
- `OSD/` (10 files) — `OsdManager.qml` (`Scope` grouping, no window)
  instantiates `VolumeOSD`, `BrightnessOSD`,
  `MicOSD`, `SpecialKeysOSD`, `GameModeOSD`,
  `BatteryOSD`; bases `BaseOSD.qml`, `PercentageOSD.qml`,
  `IconTextOSD.qml`. `SpecialKeysOSD` (Bloq Mayús / Bloq Num) se pinta
  con los avisos `KeyboardThings.capsLockRefreshed` /
  `numLockRefreshed` (cambio real detectado en la lectura de estado), no
  con el cambio de valor: así sale siempre que el estado cambia y nunca
  al arrancar.
- `WindowSwitcher/` — `Switcher.qml` alt-tab (`Scope` + IPC
  `switcher` `toggle`/`close` + `LazyLoader`-loaded `PanelWindow`,
  `cycle`/`activateCurrent`, skips non-toplevels).

All heavy features follow the `shell.qml` pattern: light `Scope` with
IPC/shortcuts at startup, `PanelWindow` instantiated lazily on open
(and destroyed on close unless explicitly cached).
