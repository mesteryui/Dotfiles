# Features

- `CheatSheet/` (5 files) — keybind cheatsheet. `Cheatsheet.qml`
  (light `Scope`: IPC `cheatsheet` `toggle`/`show`/`hide` +
  autohide + internal `LazyLoader` fullscreen `PanelWindow`) +
  `CheatsheetSheet.qml` (search via `FuzzySearch`, multi-column grid,
  `filteredCategories`, keyboard nav `moveSelection`/`moveColumn`,
  scroll helpers) + cards `CheatsheetCategoryCard` + rows
  `CheatsheetKeybindRow` + chips `CheatsheetKeyChip`.
- `Notifications/` (5 files) — `Notifications.qml` (light `Scope`:
  `LazyLoader` incubates the heavy `NotificationCenter`, popups stay
  direct per screen) + `NotificationCenter.qml` (reads
  `NotificationData.history`, visibility via
  `NotificationService.centerOpen`) + `NotificationHistoryCard.qml`
  (`M3SelectionFill` + `M3StateLayer`) + `NotificationPopups.qml` +
  `NotificationToastCard.qml`.
- `OSD/` (12 files) — `OsdManager.qml` (`Scope` grouping, no window)
  instantiates `VolumeOSD`, `BrightnessOSD`,
  `KeyboardBrightnessOSD`, `MicOSD`, `SpecialKeysOSD`, `GameModeOSD`,
  `BatteryOSD`; bases `BaseOSD.qml`, `PercentageOSD.qml`,
  `IconTextOSD.qml`, `MediaOSD.qml`.
- `WindowSwitcher/` — `Switcher.qml` alt-tab (`Scope` + IPC
  `switcher` `toggle`/`close` + `LazyLoader`-cached `PanelWindow`,
  `cycle`/`activateCurrent`, skips non-toplevels).

All heavy features follow the `shell.qml` pattern: light `Scope` with
IPC/shortcuts at startup, `PanelWindow` instantiated lazily on open
(and cached between openings).
