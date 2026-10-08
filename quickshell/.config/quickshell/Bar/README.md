# Bar

`Bar.qml` instancia una `PanelWindow` por pantalla (`Variants` sobre
`Quickshell.screens`); `MainBar.qml` es el contenido.

- `Bar.qml` — ventana por pantalla. `barType` con fallback pre-`ready`
  (`floating`); `GameMode.enabled` fuerza `no_floating`. Márgenes
  flotantes `floatingMargin: 3`, laterales de contenido
  `contentMargin: 6`. `exclusiveZone = barHeight` siempre (solo reserva
  el alto de la barra). `position` top/bottom, `height` (def. 36).
- `MainBar.qml` — ordena con `BarRegistry.sectionModules("left"|
  "center"|"right")` y crea componentes estáticos (un `Loader`
  con `source:url` no resuelve `qs.*`, por eso no se usa).
- `BarRegistry.qml` — singleton: 14 tipos canónicos (`launcher`,
  `workspaces`, `submap`, `weather`, `mpris`, `updates`, `clock`,
  `tray`, `network`, `bluetooth`, `battery`, `volume`, `caffeine`,
  `notifications`) + `defaultSections` (left/center/right/sideTop/
  sideCenter/sideBottom, idéntico a los defaults de `ConfigService`).
  `normalizeId` acepta alias (`clock/timedate/time`, `mpris/media/
  player`, `tray/systray`, `wifi/network`, `bt`, `bat`, `vol`,
  `submap/hyprlandsubmap/focus`, `updates/updatecounter/update`,
  `notif/notification`). `isModuleActive` oculta `submap` sin submapa
  y `updates` a cero. `registerModule`/`unregisterModule` para
  extensiones. `faceFile()`/`variantFaceFile()` son API informativa
  (no para `Loader.source`).
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

Config: `ConfigService.configs.bar.{position,height,barType,
workspaceButtonType,layout}`; el orden vive en `bar.layout`
(`left,center,right,sideTop,sideCenter,sideBottom`; side* reservado
para el futuro SideBar vertical). Un string suelto se acepta como
lista de un elemento; ids desconocidos se omiten con aviso.
