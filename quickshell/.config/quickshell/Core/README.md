# Core

- `Appearance.qml` — singleton de diseño. `md3` (+ `base16`,
  `palette`) desde `colors.json` generado
  (`Directories.state + "/quickshell/generated/colors.json"`).
  `shape` (`extraSmall 4` … `full 9999`, `screenRounding`,
  `windowRounding 18`, `card 20`); `state` (`hovered 0.08` /
  `pressed 0.12` / `disabled 0.38`) — nunca hardcodear `0.08/0.12`;
  `opacity` (hint/faint/ghost); `elevation1…5`; `spacing` (`xs 4`,
  `s 8`, `m 12`, `l 16`, `xl 24`); `font` + `typeScale` (label/
  body/title/headline); `motion` (duraciones short/medium/long +
  curvas `standard`/`emphasized` + springs `springSoft/Bouncy/Snappy`,
  fijos y sobrios por diseño, sin interruptores).
- `Modules/` — `Directories` (rutas config/state), `Icons`, `Persistent`
  (persistencia con debounce), `Screens`.
- `Services/` — singletons (ver `qmldir`, módulo `qs.Core.Services`):
  `AudioService`, `AuthService`, `BatteryService`, `BluetoothService`,
  `ClipboardService` (`cliphist`, `copyText`/`copyEntry` = vía única
  de copiado), `ConfigService` (`configs.*`, `ready`, `load()`),
  `DistroService`, `FuzzySearch` (+ `FuzzyMatch.js` puro),
  `GameMode`, `HyprlandKeybinds`, `HyprlandSubmap`, `Hyprsunset`,
  `I18nService`, `IdleInhibitedService`, `KeyboardThings` (`load()`),
  `LockState`, `MprisService`, `NetworkService`, `NotificationData` +
  `NotificationService`, `PolkitService`, `RandomPhraseses`,
  `SystemInfoService`, `ThemeApplier` (`init()`), `TimeService`,
  `UpdatesTracking`, `VideoFrameService` (frames de vídeo) +
  `VideoSupport` (sonda QtMultimedia), `WallpaperService`, `WeatherService`
  (+ `WeatherFormat.js` puro). Submódulo `Brightness/` (módulo
  `qs.Core.Services.Brightness`): singletons `BrightnessService`,
  `KbdBacklight` + `BrightnessMonitor` + `DdcUtils.js`.
  Lógica pura de formato en `.js` hermanos (p. ej.
  `WeatherFormat.js`), nunca dentro del singleton. Regla de
  robustez: todo `Process`/`XHR` con timeout + kill, `failed`/`error`
  explícito, sin asumir éxito fire-and-forget.
- `i18n/` — `en_US.json` (referencia, siempre completa),
  `es_ES.json`, `eo.json` (16 secciones, mismas en los tres).
  Ver `i18n/I18N.md`.
- Logging: `console.debug/info/warn/error(...)` directo. Sin wrapper.
