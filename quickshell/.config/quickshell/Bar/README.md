# Bar

`Bar.qml` instantiates one `PanelWindow` per screen (`Variants` over
`Quickshell.screens`), `MainBar.qml` holds the content.

- `Content/` — clock, player, volume, submap popups.
- `Items/` — individual bar items (launcher, clock, network, tray…).
- `SystemTray/` — tray icons + menu.
- `ScreenRounding.qml` — screen corner rounding, shares the 4-mode
  contract with `Bar.qml`: `floating` / `full_hug` / `partial_hug` /
  `no_floating` (GameMode forces `no_floating`).

Config: `ConfigService.configs.bar.{position,height,barType}`.
The bar always reserves `exclusiveZone = barHeight`.
