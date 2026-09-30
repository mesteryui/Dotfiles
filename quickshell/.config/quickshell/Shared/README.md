# Shared

`Background/` — window backgrounds (`SurfaceBackground`,
`PopupBackground`): tonal surface + corner radius + scrim handling.
Wrappers (`PanelWithControls`, bar, launcher) own the background;
`*Content.qml` files only fill it.
