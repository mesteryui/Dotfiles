# Shared

`Background/` — window backgrounds. Wrappers (`PanelWithControls`,
bar, launcher, volume…) own the background; `*Content.qml` files
only fill it.

- `SurfaceBackground` — tonal surface for panels/bars. Props:
  `active`, `highlighted`, `baseColor` (default
  `surface_container_high`), `surfaceRadius` (default
  `Appearance.shape.card`).
- `PopupBackground` — popup surface. Props: `baseColor` (default
  `surface`), `surfaceRadius` (default `shape.card`),
  `showBorder`.
