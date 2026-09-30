# Primitives

M3 building blocks. Import with `import qs.Primitives`.

Selection (single source of truth):

- `M3SelectionFill` — selected-state background. Props: `selected`,
  `selectedFill` (default `secondary_container`), `unselectedFill`
  (default transparent). Animated.
- `M3StateLayer` — hover/pressed veil. Props: `hovered`, `pressed`,
  `tint` (default `on_surface`; pass `on_secondary_container` when
  selected), `animate`. Opacities from `Appearance.state`.
- `M3ListItem` — row composing both + `MouseArea` + content slot.
  Signals `clicked/entered/exited/pressed/released`. Props
  `accessibleRole`/`accessibleName` (defaults: Button/""). For delegates
  with custom hover timing (e.g. launcher `ResultList`) use the two parts
  directly instead. Used by e.g. Bluetooth device rows.

Contrast rule (M3 list):

- selected → fill `secondary_container`, text/icons `on_secondary_container`;
- unselected → icons `primary`, title `on_surface`, subtitle `on_surface_variant`.
- Hover/press is always a state layer, never a fill change.

Accessibility (quickshell `Accessible` attached props, same convention
everywhere):

- rows/options → `ListItem`/`Option` + `name` (+ `description`); tabs →
  `PageTab`; toggle rows → `RadioButton` + `checked`; buttons → `Button`;
- search fields → `Accessible.name: placeholderText`.

Other: `M3Card`, `AnimatedIconButton/TextButton`, `ButtonIcon`,
`ControlSlider/Toggle/Switch`, `MaterialIcon`, `StyledText(/Area)`,
`StyledScrollBar/ProgressBar`, `AppIcon`, `BarPopupWindow`, `Revealer`.
