# scripts

- `qml-lint-conventions.py` — Qt QML ordering lint. Enforces member
  order per object (with blank line between sections): 1. `id`,
  2. properties, 3. signals, 4. functions, 5. bindings,
  6. child objects, 7. component definitions. Run before committing
  QML. (M3 token discipline — `Appearance.md3/state/shape/motion`,
  no magic opacities — is a code-review rule, see root `README.md`.)
- `location.py` — Geoclue helper for weather: `obtain_cordinates()`
  returns `latitud`/`longitud`/`precision` (Neighborhood accuracy).

QML style is enforced via `.qmlformat.ini` (spaces, indent 4, Unix
newlines, max column 110) / `.qmlls.ini` at the shell root.

Note: the emoji catalog generator lives in
`Launcher/scripts/emoji-dump.py`, not here.
