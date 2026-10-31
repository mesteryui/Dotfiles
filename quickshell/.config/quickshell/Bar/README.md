# Bar

`Bar.qml` instancia una `PanelWindow` por pantalla (`Variants` sobre
`Quickshell.screens`); `MainBar.qml` es el contenido.

- `Bar.qml` — ventana por pantalla. `barType` con fallback pre-`ready`
  (`floating`); `GameMode.enabled` fuerza `no_floating`. Márgenes
  flotantes `floatingMargin: 2`, laterales de contenido
  `contentMargin: 5` (`notch`: `notchOuterRadius + 4`). `exclusiveZone
  = barHeight` siempre (solo reserva el alto de la barra). `position`
  top/bottom, `height` (def. 36). La píldora flotante lleva hairline de
  `Appearance.border`; en los modos hug el trazo lo aporta el marco de
  `ScreenRounding`. En `notch` el fondo es `NotchBackground`: el borde
  de pantalla ocupa todo el ancho y se une a los laterales con
  esquinas cóncavas de `notchOuterRadius`; el cuerpo queda retirado ese
  radio a cada lado y sus esquinas interiores se redondean con
  `notchInnerRadius`, así que la silueta no acaba en un corte recto. La
  ventana lleva un `mask: Region` con la misma silueta (incluido el
  redondeo interior) para que los huecos dejen pasar los clics.
- `MainBar.qml` — contenido: 3 zonas (left/center/right) con
  componentes directos de `Items/`.
- `Content/` — popups de cada módulo (9): `Battery`, `Clock`,
  `HyprlandSubmap`, `Network`, `Player`, `UpdateCounter`, `Volume`,
  `Weather`, `WorkspaceButton`.
- `Items/` — caras de barra (13 + base `BarItem.qml`): `Battery`,
  `Bluetooth`, `Clock`, `HyprlandSubmap`, `Launcher`,
  `MprisPlayer`, `Network`, `SysTray`, `UpdateCounter`,
  `Volume`, `Weather`, `WorkspaceButton`, `Workspaces` (+ `Workspaces`
  es el contenedor y `WorkspaceButton` el botón).
- `Items/BarPopup.qml` — `LazyLoader` de popup de barra. Carga de forma
  asíncrona al abrir o pulsar (el hover no precarga) y expone
  `opened`/`toggle()`. `syncVisible()` es la única función que escribe
  `visible`, y solo lo hace cuando `active` es true (popup ya
  instanciado): nunca se lee `.item` durante la carga. Un único timer
  de gracia (`graceMs`, def. 1200) retiene un popup ya cargado tras
  cerrarse, sin iniciar cargas nuevas; `hovered`/`pressed` lo
  conservan sin consumir la gracia. El componente cargado debe ser un
  `BarPopupWindow` (usa `visible`/`anchorItem`).
- `SystemTray/` — `SysTray.qml` + `SysTrayItem.qml` + `TrayMenu.qml`.
- `ScreenRounding.qml` — redondeo/bordes por pantalla. Lee
  `ConfigService.configs.bar.{barType,position}` (`activeBarType`,
  con override de GameMode). Contrato de 5 modos compartido con
  `Bar.qml`: `floating` (píldora; aquí no se dibuja nada),
  `full_hug` (marco + esquinas en ambos lados), `partial_hug`
  (esquinas solo en el lado de la barra, sin marco), `notch` (barra
  completa con esquinas propias en `Bar.qml`; aquí no se dibuja nada),
  `no_floating` (nada). Dimensiones por tokens de `Appearance.shape`:
  `screenBorder` = grosor de las bandas del marco (`full_hug`),
  `screenRounding` = radio de las esquinas. Nota histórica:
  `isFloating` aquí significa `full_hug`, distinto del `isFloating`
  (`floating`) de `Bar.qml`.
- `ScreenCorner.qml` — esquina (`Shape`, `cornerRadius`, `fillColor`,
  `mirrorX`/`mirrorY`).
- `NotchBackground.qml` — fondo del modo `notch` (`Shape` con la
  silueta cóncava, `fillColor`, `cornerRadius` para las esquinas del
  borde de pantalla, `bodyRadius` para las del cuerpo y `atTop`). El
  cuerpo se dibuja con la muesca arriba y se refleja cuando la barra
  está abajo. Radios acotados a la geometría para que los arcos no se
  solapen en barras bajas o ventanas de 0px en el primer frame.

Config: `ConfigService.configs.bar.{position,height,workspaceButtonType,barType}`.
