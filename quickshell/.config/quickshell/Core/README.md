# Core

- `Appearance.qml` — singleton de diseño. `md3` (+ `base16`,
  `palette`) desde `colors.json` generado
  (`Directories.state + "/quickshell/generated/colors.json"`).
  `shape` (radios ascendentes: `micro 2`, `extraSmall 4`, `small 8`,
  `medium 12`, `large 17`, `extraLarge 23`, `huge 30`, `full 9999`;
  `screenRounding` = `extraLarge`, `windowRounding 18`,
  `screenBorder 14`; `card 20` = `largeIncreased` de caelestia para
  popups/menús compactos); `border`
  (trazo hairline `width 1`, `focusWidth 2`; colores `subtleOn(fondo)` /
  `strong` / `focus` / `selected` / `error` / `divider`); `state`
  (`hovered 0.08` /
  `pressed 0.12` / `disabled 0.38`) — nunca hardcodear `0.08/0.12`;
  `opacity` (hint/faint/ghost); `elevation1…5`; `spacing` (`extraSmall 4`,
  `small 8`, `medium 12`, `large 16`, `extraLarge 24`); `font` +
  `typeScale` (label/body/title/headline; `font.pixelSize` para
  iconos/display: `large 17`, `larger 19`, `huge 22`, `massive 23`);
  `motion` (duraciones por velocidad: `instant 50`, `veryFast 100`,
  `fast 150`, `normal 200`, `relaxed 250`, `slow 300`, `verySlow 350`,
  `slowest 450`; curvas `standard`/`emphasized` + springs
  `springSoft/Bouncy/Snappy`, fijos y sobrios por diseño, sin
  interruptores).
- `Modules/` — `Directories` (rutas config/state), `Icons`, `Persistent`
  (persistencia con debounce), `Screens`.
- `Services/` — singletons (ver `qmldir`, módulo `qs.Core.Services`):
  `AudioService`, `AuthService`, `BatteryService`, `BluetoothService`,
  `ClipboardService` (`cliphist`, `copyText`/`copyEntry` = vía única
  de copiado), `ConfigService` (`configs.*`, `ready`, `load()`),
  `DistroService`, `FuzzySearch` (+ `FuzzyMatch.js` puro),
  `GameMode`, `HyprlandKeybinds`, `HyprlandSubmap`, `Hyprsunset`,
  `I18nService`, `IdleInhibitedService`, `KeyboardThings` (Bloq Mayús /
  Bloq Num: lee `j/devices` por `HyprlandIpc` y guarda el estado POR
  TECLADO —Hyprland lo reporta por dispositivo, no global—, detecta
  cuál cambió y avisa con `capsLockRefreshed` / `numLockRefreshed`;
  vía rápida = atajos globales `quickshell:capsLock` /
  `quickshell:numLock`, red de seguridad = sondeo de 350 ms),
  `LockState`, `MprisService`, `NetworkService`, `NotificationData` +
  `NotificationService`, `PolkitService`, `RandomPhraseses`,
  `SystemInfoService`, `ThemeApplier` (`init()`), `TimeService`,
  `UpdatesTracking`, `VideoFrameService` (frames de vídeo) +
  `VideoSupport` (sonda QtMultimedia), `WallpaperColorService` (color
  dominante por fondo, caché vía `scripts/wallpaper-scan.py`),
  `WallpaperService`, `WeatherService`
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
