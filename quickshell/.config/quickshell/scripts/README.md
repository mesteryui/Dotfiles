# scripts

- `check.sh` — chequeo unificado de calidad: `qmllint` Qt6 (sintaxis),
  `qmlformat` Qt6 (formato `.qmlformat.ini`), `qml-lint-conventions.py`
  (informativo por defecto, `--strict` para fallar), JSON `Core/i18n`,
  JS vía `qmllint` (dialecto QML con `.pragma library`), y grep de
  colores hardcodeados. Uso: `scripts/check.sh [--fix] [--strict]`.
  Tarda ~15s. Importante: usa los binarios Qt6 (`/usr/lib/qt6/bin`);
  `/usr/bin/qmllint` es Qt5 y aborta con `pragma ComponentBehavior`.
  También falla si `qmllint` reporta `Unqualified access [unqualified]`:
  los miembros declarados en un ancestro se acceden siempre como
  `idRaiz.miembro` (convención de claridad de origen de cada elemento).
- `qmlls-sync.sh` — copia al VFS de quickshell (`buildDir` de
  `.qmlls.ini`) los `qmldir` manuales (`Core/Services`, `Brightness`)
  que quickshell no sintetiza. Sin esto el editor no resuelve
  `import qs.Core.Services` y marca los servicios como desconocidos.
  Idempotente; lo lanza `shell.qml` al arrancar y se puede correr a mano.
- `qml-lint-conventions.py` — Qt QML ordering lint. Enforces member
  order per object (with blank line between sections): 1. `id`,
  2. properties, 3. signals, 4. functions, 5. bindings,
  6. child objects, 7. component definitions. Run before committing
  QML. (M3 token discipline — `Appearance.md3/state/shape/motion`,
  no magic opacities — is a code-review rule, see root `README.md`.)
- `location.py` — Geoclue helper for weather: `obtain_cordinates()`
  returns `latitud`/`longitud`/`precision` (Neighborhood accuracy).
- `sync-system-fonts.sh [SANS MONO]` — sistema de fuentes centralizado:
  vuelca la fuente de la shell (`shinro/config.json` →
  `appearance.fontSans`/`monospace`; sin argumentos la lee) a fontconfig
  (`conf.d/90-shell-fonts.conf`, aliases sans-serif/system-ui/monospace;
  el prefijo `90-` ordena antes de `99-default-fonts.conf` y en
  fontconfig el primer archivo leído gana en `<alias><prefer>`),
  qtengine (`theme.font`/`fontFixed`, solo la familia) y GTK
  (`gtk-font-name` en `gtk-3.0`/`gtk-4.0` `settings.ini` + `gsettings`,
  conservando el tamaño de cada destino). Idempotente, con `flock` y
  escrituras atómicas. Lo lanza `FontSyncService` al arrancar la shell y
  al cambiar la fuente en Ajustes; las apps abiertas no recargan, surten
  efecto al reabrirlas.
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
