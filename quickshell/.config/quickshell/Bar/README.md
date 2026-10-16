# Bar

`Bar.qml` instancia una `PanelWindow` por pantalla (`Variants` sobre
`Quickshell.screens`); `MainBar.qml` es el contenido.

- `Bar.qml` — ventana por pantalla. `barType` con fallback pre-`ready`
  (`floating`); `GameMode.enabled` fuerza `no_floating`. Márgenes
  flotantes `floatingMargin: 3`, laterales de contenido
  `contentMargin: 6`. `exclusiveZone = barHeight` siempre (solo reserva
  el alto de la barra). `position` top/bottom, `height` (def. 36).
- `MainBar.qml` — contenido: 3 zonas (left/center/right) con
  componentes directos de `Items/`.
- `Content/` — popups de cada módulo (11): `Battery`, `Caffeine`,
  `Clock`, `HyprlandSubmap`, `Network`, `Notifications`, `Player`,
  `UpdateCounter`, `Volume`, `Weather`, `WorkspaceButton`.
- `Items/` — caras de barra (16 + base `BarItem.qml`): `Battery`,
  `Bluetooth`, `Caffeine`, `Clock`, `HyprlandSubmap`, `Launcher`,
  `MprisPlayer`, `Network`, `Notifications`, `SysTray`, `UpdateCounter`,
  `Volume`, `Weather`, `WorkspaceButton`, `Workspaces` (+ `Workspaces`
  es el contenedor y `WorkspaceButton` el botón).
- `SystemTray/` — `SysTray.qml` + `SysTrayItem.qml` + `TrayMenu.qml`.
- `ScreenRounding.qml` — redondeo/bordes por pantalla. Lee
  `ConfigService.configs.bar.{barType,position}` (`activeBarType`,
  con override de GameMode). Contrato de 4 modos compartido con
  `Bar.qml`: `floating` (píldora; aquí no se dibuja nada),
  `full_hug` (esquinas + líneas siempre), `partial_hug` (esquinas
  solo en el lado de la barra), `no_floating` (nada). Nota histórica:
  `isFloating` aquí significa `full_hug`, distinto del `isFloating`
  (`floating`) de `Bar.qml`.
- `ScreenCorner.qml` — esquina (`Shape`, `cornerRadius`, `fillColor`,
  `mirrorX`/`mirrorY`).

Config: `ConfigService.configs.bar.{position,height,workspaceButtonType,barType}`.
