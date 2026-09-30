# quickshell — shinro shell

Modular Quickshell shell (Hyprland): bar, control dashboard, launcher,
lockscreen, notifications, media, settings.

- `Bar/` — top/bottom bar (`Bar.qml`, `MainBar.qml`, items, tray).
- `Core/` — `Appearance.qml` (M3 tokens), `Modules/`, `Services/`, `i18n/`.
  See `Core/README.md` and `Core/i18n/I18N.md`.
- `Launcher/` — fuzzy launcher (apps, system menus, files, web, emoji,
  calc, clipboard). See `Launcher/README.md`; full menu authoring guide
  (Spanish) in `Launcher/GUIA-MENUS.md`, English short version in
  `Launcher/GUIDE-MENUS.md`.
- `Panels/` — control center, volume, bluetooth, media, calendar, weather,
  wallpaper, updates, notifications, polkit, system.
- `Features/` — cheatsheet, notifications, OSD, window switcher.
- `Lockscreen/` — lock screen.
- `Windows/` — settings panel.
- `Primitives/` — M3 building blocks (`M3Card`, `M3ListItem`,
  `M3SelectionFill`, `M3StateLayer`, sliders, toggles, icons, text).
- `Shared/` — backgrounds.
- `scripts/` — lint (`qml-lint-conventions.py`), helpers (`location.py`).

Conventions: M3 tokens via `Appearance.md3`, state opacities via
`Appearance.state`, shapes via `Appearance.shape`, motion via
`Appearance.motion`. Selection rule: selected → `secondary_container`
fill + `on_secondary_container` content; hover/press → state layer
(`M3StateLayer`), never a fill change.
