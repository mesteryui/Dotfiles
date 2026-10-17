# Panels

One folder per surface. Wrappers own the background (`Shared/`) and
the window (`Scope` + `LazyLoader` + `PanelWindow`); `*Content.qml`
files only fill it.

- `Controls/` — control center. Wrapper `PanelWithControls.qml`
  (`Scope` + IPC `dashboard` toggle, `PanelWindow` lazy) +
  `PanelWithControlsContent.qml` (fixed header + per-tab scroll:
  `ControlsHeader`, `ControlsSliders`, `ControlsTogglesGrid`,
  `ControlsTabBar`; 2 tabs: `Tabs/SysInfoTab`, `Tabs/WeatherTab`;
  reusable bits `Tabs/CpuArc`).
- `Volume/` — `VolumeCenter.qml` (`Scope` + `GlobalShortcut`
  `audio_panel` + `LazyLoader`) + `VolumePanel.qml` +
  `VolumePopupContent.qml`.
- `Bluetooth/` — `BluetoothPanel.qml` + `BluetoothPopupContent.qml`.
- `MediaPlayer/` — `MprisContent.qml` (active/multi player,
  shuffle/loop via `MprisService`) + `MprisSubwindow.qml`.
- `Calendar/` — `CalendarContent.qml` + `CalendarPopupWindow.qml`.
- `Weather/` — `WeatherPopup.qml` + `WeatherPopupContent.qml` +
  `WeatherAlerts.qml`.
- `Wallpaper/` — `WallpaperMenu.qml` (`Scope` + IPC
  `ui.wallpaperMenu` + `LazyLoader`) + `WallpaperItem.qml` +
  `WallpaperLayer.qml` + `WallpaperLayerScreen.qml` + `Content/`
  (`WallpaperMenuContent` — carrusel + estado de filtros/búsqueda,
  `WallpaperFilterBar` — tipo (todos/imágenes/vídeos) y color dominante,
  `WallpaperItemContent`) + vídeo opcional:
  `AnimatedWallpaperPlayer.qml` (único con `import QtMultimedia`, carga
  aislada por `Loader`), frames vía `VideoFrameService` + script
  `scripts/extract-wallpaper-frame.sh`, disponibilidad en `VideoSupport`.
  El filtro por color usa `WallpaperColorService` + script
  `scripts/wallpaper-scan.py` (caché incremental en State).
- `Updates/` — `UpdateList.qml` + `UpdateListHeader.qml` +
  `UpdateListFooter.qml` + `Content/` (`UpdateListContent`,
  `UpdateListHeaderContent`, `UpdateFooterContent`,
  `UpdateListPackages`, `UpdatePackageDelegate`).
- `Notifications/` — `NotificationPopupContent.qml` +
  `NotificationPopupWindow.qml` (popups per-screen; the center lives
  in `Features/Notifications/`).
- `Polkit/` — `PolkitWindow.qml` (`Scope` + `LazyLoader`, auth agent
  vs `PolkitService`) + `PolkitContent.qml`.
- `System/` — `PowerButtons.qml` (`Scope` + IPC `ui.powermenu`,
  fullscreen overlay, `LazyLoader`) + `GenericButton.qml`.
- `Battery/` — `BatteryPopupContent.qml` + `BatteryPopupWindow.qml`.

Selection rule everywhere: `M3SelectionFill` (+ `on_secondary_container`
content when selected) and `M3StateLayer` for hover/press. See
`Primitives/README.md`.
