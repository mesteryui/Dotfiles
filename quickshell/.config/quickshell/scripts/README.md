# scripts

- `check.sh` — chequeo unificado de calidad: `qmllint` Qt6 (sintaxis),
  `qmlformat` Qt6 (formato `.qmlformat.ini`), `qml-lint-conventions.py`
  (informativo por defecto, `--strict` para fallar), JSON `Core/i18n`,
  JS vía `qmllint` (dialecto QML con `.pragma library`), y grep de
  colores hardcodeados. Uso: `scripts/check.sh [--fix] [--strict]`.
  Tarda ~15s. Importante: usa los binarios Qt6 (`/usr/lib/qt6/bin`);
  `/usr/bin/qmllint` es Qt5 y aborta con `pragma ComponentBehavior`.
- `qml-lint-conventions.py` — Qt QML ordering lint. Enforces member
  order per object (with blank line between sections): 1. `id`,
  2. properties, 3. signals, 4. functions, 5. bindings,
  6. child objects, 7. component definitions. Run before committing
  QML. (M3 token discipline — `Appearance.md3/state/shape/motion`,
  no magic opacities — is a code-review rule, see root `README.md`.)
- `location.py` — Geoclue helper for weather: `obtain_cordinates()`
  returns `latitud`/`longitud`/`precision` (Neighborhood accuracy).
- `extract-wallpaper-frame.sh <video> <salida.jpg>` — frame fijo del
  segundo 1 para fondos animados (póster, lockscreen, matugen).
  Idempotente: si la salida existe y es más nueva que el vídeo, sale 0
  sin reescribir.
- `wallpaper-scan.py --cache <json> --dir <carpeta>` — color dominante
  (tono + hex + luma) de cada fondo, imágenes (ImageMagick) y vídeos
  (ffmpeg). Caché incremental por `mtime`+`tamaño`: solo decodifica lo
  nuevo o modificado. Alimenta el filtro por color del selector
  (`WallpaperColorService`). Sin herramientas o con un fichero roto
  omite ese fondo, nunca aborta el escaneo.

QML style is enforced via `.qmlformat.ini` (spaces, indent 4, Unix
newlines, max column 110) / `.qmlls.ini` at the shell root.

Note: the emoji catalog generator lives in
`Launcher/scripts/emoji-dump.py`, not here.
