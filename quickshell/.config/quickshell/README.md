# quickshell — shinro shell

Modular Quickshell shell (Hyprland): bar, control dashboard, launcher,
lockscreen, notifications, media, settings.

- `shell.qml` — root: `Scope` ligero por feature con `LazyLoader`
  interno (IPC/atajos responden al arranque, la `PanelWindow` solo se
  instancia al abrir). `settings.watchFiles: false`. Al arrancar:
  `ConfigService.load()`, `ThemeApplier.init()`. Incluye `Switcher`,
  `AppLauncher`, `SettingsPanel`, `PanelWithControls`, `VolumeCenter`, `OsdManager`,
  `WallpaperMenu`, `ScreenRounding`, `PowerButtons`, `Notifications`,
  `Cheatsheet`, `PolkitWindow`, `WallpaperLayer`, `Bar`, `LockScreen`.
- `Bar/` — una `PanelWindow` por pantalla (`Bar.qml` + `MainBar.qml`,
  items, tray, redondeo). Ver `Bar/README.md`.
- `Core/` — `Appearance.qml` (tokens M3), `Modules/` (`Directories`,
  `Icons`, `Persistent`, `Screens`), `Services/` (31 singletons +
  submódulo `Brightness/`), `i18n/` (`en_US.json` referencia,
  `es_ES.json`, `eo.json`). Ver `Core/README.md` y `Core/i18n/I18N.md`.
- `Launcher/` — buscador unificado de 7 modos (apps, menús `>`,
  archivos `/`, web `@`, emoji `.`, calc `=`, clipboard `:`). Ver
  `Launcher/README.md`; guía de autoría de menús (español) en
  `Launcher/GUIA-MENUS.md`, resumen en inglés en
  `Launcher/GUIDE-MENUS.md`. Catálogo emoji generado en runtime por
  `Launcher/scripts/emoji-dump.py`.
- `Panels/` — 11 superficies: `Battery`, `Bluetooth`, `Calendar`,
  `Controls` (dashboard), `MediaPlayer`, `Polkit`, `System` (powermenu),
  `Updates`, `Volume`, `Wallpaper`, `Weather`. Ver `Panels/README.md`.
- `Features/` — `CheatSheet`, `Notifications` (centro + toasts),
  `OSD` (7 OSDs + `OsdManager`), `WindowSwitcher`. Ver
  `Features/README.md`.
- `Lockscreen/` — bloqueo por pantalla (`LockScreen.qml` + wrapper,
  contenido, vistas sleep/auth, gesto, fondo, reloj, MPRIS).
  Ver `Lockscreen/README.md`.
- `Windows/` — panel de ajustes (4 pestañas). Ver `Windows/README.md`.
- `Primitives/` — bloques M3 (`M3SelectionFill`, `M3StateLayer`,
  `M3ListItem`, botones, controles, textos, barras, iconos,
  `BarPopupWindow`, `Revealer`…). Ver `Primitives/README.md`.
- `Shared/` — fondos (`SurfaceBackground`, `PopupBackground`).
  Ver `Shared/README.md`.
- `scripts/` — lint Qt-QML (`qml-lint-conventions.py`), ubicación por
  Geoclue (`location.py`). Ver `scripts/README.md`.
- `assets/` — iconos de distro (`distro-*.svg`, `cachyos-symbolic.svg`).

IPC (`qs ipc call …`): `launcher` (toggle/toggleMode/openClipboard/
openEmoji/openSystem/openMenu/reloadMenus), `dashboard` (toggle),
`cheatsheet` (toggle/show/hide), `switcher` (toggle),
`ui.settings`, `ui.powermenu`, `ui.wallpaperMenu` (toggleWallpaperMenu),
`lockscreen`.

Conventions: tokens vía `Appearance.md3` (+ `base16`, `palette`;
nunca hardcodear), opacidades de estado vía `Appearance.state`
(`hovered 0.08` / `pressed 0.12` / `disabled 0.38`), formas/radios vía
`Appearance.shape` (radios ascendentes: micro 2,
extraSmall 4, small 8, medium 12, large 17, extraLarge 23, huge 30),
motion vía `Appearance.motion` (duraciones y springs
fijos, sobrios por diseño), bordes vía `Appearance.border` (hairline
1px en superficies flotantes; color `subtleOn(fondo)`, nunca
`outline_variant` a plena intensidad), spacing vía `Appearance.spacing`, fuentes vía
`Appearance.font`/`typeScale`. Selección: selected →
`secondary_container` fill (`M3SelectionFill`) +
`on_secondary_container` contenido; hover/press → state layer
(`M3StateLayer`), nunca cambio de fill. Orden QML (ver
`scripts/qml-lint-conventions.py`): id → properties → signals →
functions → bindings → hijos → componentes. Estilo en
`.qmlformat.ini` / `.qmlls.ini`. Config en
`ConfigService.configs` (`bar`, `appearance`, `language`, …).
Logging: `console.debug/info/warn/error(...)` directo, sin wrapper.
Regla de robustez: todo `Process`/`XHR` con timeout + kill, error
explícito, sin asumir éxito fire-and-forget.
