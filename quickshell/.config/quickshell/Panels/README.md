# Panels

One folder per surface; `*Content.qml` holds the UI, thin wrappers hold
`Scope` + IPC + `PanelWindow`:

- `Controls/` — control center (`PanelWithControls.qml` wrapper +
  `PanelWithControlsContent.qml`). Fixed header + per-tab scroll:
  `ControlsHeader`, `ControlsSliders`, `ControlsTogglesGrid`,
  `ControlsTabBar` (each takes `host` = content root; focus chained via
  aliases), tabs (`Tabs/SysInfoTab`, `Tabs/WeatherTab`).
- `Volume/`, `Bluetooth/`, `MediaPlayer/`, `Calendar/`, `Weather/`,
  `Wallpaper/`, `Updates/`, `Notifications/`, `Polkit/`, `System/`,
  `Battery/`.

Selection rule everywhere: `M3SelectionFill` (+ `on_secondary_container`
content when selected) and `M3StateLayer` for hover/press. See
`Primitives/README.md`.
