# Core

- `Appearance.qml` — singleton: M3 tokens (`md3`, generated
  `colors.json`), `shape`, `state` (hovered/pressed/disabled),
  `motion`, `spacing`, fonts. Never hardcode `0.08/0.12` — use
  `Appearance.state`.
- `Modules/` — `Directories`, `Icons`, `Persistent`, `Screens`.
- `Services/` — singletons: audio, battery, bluetooth, brightness,
  clipboard (`cliphist`), config, distro, fuzzy search, gamemode,
  hyprland (keybinds, submap, sunset), i18n, mpris, network, notifications,
  polkit, system info, theme, updates, wallpaper, weather.
  Pure formatting/logic helpers live in sibling `.js` (e.g.
  `WeatherFormat.js`), never inside the singleton.
  Robustness rule: every `Process`/`XHR` gets timeout + kill, explicit
  `failed`/`error`, no fire-and-forget success assumptions.
- `i18n/` — `en_US.json` (reference), `es_ES.json`, `eo.json`.
  See `i18n/I18N.md` for key conventions and fallback.
- Logging: `console.debug/info/warn/error(...)` directo. Sin wrapper.
