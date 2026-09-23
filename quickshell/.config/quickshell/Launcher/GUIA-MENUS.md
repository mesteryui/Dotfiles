# Launcher / Quickshell — Guía completa de funcionamiento y creación de menús

> Para alguien que apenas sabe programar. Extensa, pero sin rodeos.

## 0. La idea en 30 segundos

`Launcher/` es **una ventanita buscadora** que se abre con el teclado (estilo Spotlight).

Tú escribes, él filtra, pulsas `Enter` y ejecuta algo: abrir una app, copiar un emoji, pegar del portapapeles, abrir un archivo, calcular `45*1.21`, buscar en la web o tocar un ajuste del sistema.

Analogía de restaurante:

* **AppLauncher.qml** = el camarero y el local (lo que ves y lo que hace al pulsar).
* **MenuModes.js** = la carta dividida en secciones (menús).
* **SystemMenuRegistry.qml** = el jefe de cocina que junta todas las recetas.
* **MenuProviders/System/*.qml** = recetas internas (estáticas o dinámicas,
  todas heredan `MenuDefinition`, igual que las tuyas).
* **MenuProviders/*.qml (tus archivos)** = TUS menús. Todo unificado bajo `MenuProviders/`.
* **MenuStore.qml (UnifiedMenuStore) + `MenuDefinition`** = SISTEMA ÚNICO: aquí viven
  **todos los menús personalizados** (todo lo que NO es Archivos, Aplicaciones,
  Calculadora, Web, Emojis, Clipboard), sean internos o tuyos, estáticos o dinámicos.
* **MenuProviders/new-menu.sh** = generador: `new-menu.sh MiMenu "Mi menú"` crea el archivo por ti.
* **FilePreviewService.qml** = el fotógrafo que hace miniaturas.
* **EmojiService.qml** = servicio del selector de emojis: genera el
  catálogo en runtime con un programa (ver §9), grupos, recientes,
  favoritos, ranking y copia. Sin datos hardcodeados en JS.
* **EmojiCustom.js** = TUS emojis/símbolos (tu config, prioridad máxima).
* **scripts/emoji-dump.py** = el programa: vuelca emojis de la librería
  `emoji` de PyPI + símbolos de la stdlib `unicodedata`.

Todo vive en:

```
~/.config/quickshell/Launcher/
├── AppLauncher.qml          # ventana + estado + dispatch + interfaz
├── LauncherPreview.qml      # orquesta el preview lateral (estado + debounce)
├── MenuDefinition.qml       # componente base (herédalo, no lo copies)
├── MenuStore.qml            # descubre todos los menús automáticamente
├── SystemMenuRegistry.qml   # fachada única: solo lee MenuStore
├── FilePreviewService.qml   # miniaturas de archivos
├── EmojiService.qml         # servicio del selector de emojis (ver §9)
├── EmojiCustom.js           # TUYOS (prioridad máxima, edita este)
├── Base/                    # lógica sin estado ni UI
│   ├── MenuModes.js         # qué menús existen y con qué letra se activan
│   ├── ItemKinds.js         # predicados sobre items (clip/imagen/texto…)
│   ├── LauncherApps.js      # orden y dedup de .desktop
│   └── ShellUtils.js        # shellEscape/fileUrl (única implementación)
├── Modes/                   # un modo = su lógica (qalc, fd…)
│   ├── LauncherCalc.qml     # calculadora vía qalc
│   ├── LauncherFileSearch.qml # búsqueda con fd + snapshot
│   └── FileMenu.js          # mapeo/orden del modo archivos
├── UI/                      # componentes visuales reutilizables
│   ├── ResultList.qml       # lista + navegación + flash de borde
│   └── PreviewPanel.qml     # panel lateral de preview
├── scripts/emoji-dump.py    # programa: genera el catálogo en runtime
│                            # (librería `emoji` + stdlib `unicodedata`)
├── MenuProviders/           # SISTEMA ÚNICO (todo aquí dentro)
│   ├── new-menu.sh          # generador: ./new-menu.sh MiMenu "Mi menú"
│   ├── System/              # 10 internos (7 estáticos + 3 dinámicos, heredan MenuDefinition)
│   └── MiMenu.qml           # tus menús (heredan MenuDefinition)
```
(No hay nada más: el antiguo `SystemMenu/*.js` se eliminó; la fuente de
verdad son los `MenuProviders/*.qml`. Si algún doc viejo lo menciona,
ignóralo.)

---

## 1. Conceptos mínimos para entender el código

Si nunca programaste en QML/JS, quédate con esto:

| Concepto | Qué es, en cristiano |
|---|---|
| `QML` (`.qml`) | Lenguaje para describir ventanas. Mezcla "cómo se ve" (botones, listas) con "qué hace" (funciones). |
| `JS` (`.js`) | Lógica pura: listas, textos, funciones. Sin ventana. |
| `property` | Una variable guardada en la ventana. Ej: `property string query` = "lo que has escrito sin el prefijo". Si cambia, todo lo que depende de ella se recalcula solo. |
| `function` | Una receta: le das ingredientes, te devuelve algo o hace algo. |
| `Singleton` | Un objeto único en todo el programa. `MenuStore` hay uno solo, todos le preguntan a él. |
| `import` | "Necesito usar código de otro archivo". |
| `Process` + `SplitParser` | "Ejecuta un comando de terminal y lee su salida línea a línea". Así el launcher habla con `fd`, `qalc`, `fastfetch`, `ffmpeg`, etc. |
| `ListModel` | Una lista visible para QML. Peligro: si la cambias 100 veces seguidas, la interfaz se vuelve loca (binding loops). Por eso el código usa "snapshots" (fotos fijas de la lista). |
| `IPC` (`qs ipc call ...`) | Mensajes entre partes del shell. Ej: `qs ipc call cheatsheet toggle` = "oye, cheatsheet, ábrete/ciérrate". |
| `FuzzySearch` | Buscador tolerante: si escribes `stre`, encuentra `Steam`. No exige que escribas perfecto. |
| `binding` | Fórmula automática. Ej: `activeMode` se recalcula solo cuando cambias el texto. Tú no la llamas, ella se entera. |

---

## 2. `MenuModes.js` — la base común de todos los menús

Este es el archivo más pequeño y más importante para entender los menús.

Cada menú es **distinto por dentro, igual por fuera**. Todos comparten 3 datos:

```js
{ modeId: "system", selectorChar: ">", previewMode: "conditional" }
```

* `modeId`: nombre interno. Hay 7 fijos: `todo, system, files, web, emoji, calc, clip`.
* `selectorChar`: la letra mágica. Si tu texto empieza por ella, cambias de menú.
* `previewMode`: si el panel derecho de vista previa es `always` / `conditional` / `never`.

Tabla real (`defs()`):

| Menú | Prefijo | Qué busca | Preview |
|---|---|---|---|
| `todo` | *(ninguno, es el defecto)* | Solo apps instaladas (`.desktop`) | nunca |
| `system` | `>` | Ajustes del sistema (secciones, ver §5) | solo si el item trae `imagePath` (ej. temas fastfetch) |
| `files` | `/` | Archivos de tu `$HOME` con `fd` | solo imagen/texto/pdf/audio/video |
| `web` | `@` | DuckDuckGo + abrir URL directa | nunca |
| `emoji` | `.` | Emojis/símbolos → `wl-copy` (vía EmojiService) | nunca |
| `calc` | `=` | Calculadora con `qalc` → copia resultado | nunca |
| `clip` | `:` | Historial `cliphist` (texto + imágenes) | siempre |

Funciones que expone:

* `prefixOf(modeId)` → te dice el prefijo. Ej: `prefixOf("files")` = `"/"`.
* `modeForPrefix(text)` → mira el texto y dice en qué menú estás. Ej: `"> apa"` → `"system"`.
* `supportsPreview(modeId)` → ¿este menú *puede* tener preview?
* `needsPreview(modeId, item)` → ¿*este item concreto* lo necesita? Esta es la que usa el panel lateral para decidir si ensancharse a 900px o quedarse en 600px.

> Idea clave: si algún día quieres un 8º menú, aquí es donde se declararía. Pero los **menús personalizados del sistema NO necesitan tocar esto**: van por otra vía (ver §6).

---

## 3. `AppLauncher.qml` — la ventana, el cerebro y la lista (~1285 líneas)

Es el archivo grande. Hazlo en capas:

### 3.1. Es una ventana especial

```qml
PanelWindow { id: launcher; property bool launcherVisible: false; ... }
```

* Ocupa toda la pantalla transparente, pero el cuadro real es de `600px` (o `900px` con preview) x `640px`.
* Clic fuera = cerrar (`MouseArea`).
* `HyprlandFocusGrab` + `WlrLayershell` = "mientras estoy abierto, el teclado es mío".
* `IpcHandler { target: "launcher" }` = se puede controlar desde terminal/atajos:

```
qs ipc call launcher toggle
qs ipc call launcher openSystem
qs ipc call launcher openEmoji
qs ipc call launcher openClipboard
qs ipc call launcher openMenu appearance
qs ipc call launcher toggleMode files   # también: web, calc, clip, emoji, system, todo
qs ipc call launcher reloadMenus   # manual: re-escanea MenuProviders/ (lo normal es que no haga falta: hay recarga en vivo)
```

`toggleMode(name)` es la lógica de "si ya estoy en ese menú, cierro; si no, abro
y dejo su carácter (`> / @ . = :`) en el campo, igual que pulsar su chip".

### 3.2. ¿En qué menú estoy? ¿Qué busco?

Tres propiedades encadenadas:

1. `typedMode()` = ¿el texto empieza por `> / @ . = :`? Eso **manda siempre**.
2. `activeMode` = si hay prefijo, ese; si no, `forcedMode` (el que pidió el IPC); si no, `"todo"`.
3. `query` = el texto **sin** el prefijo y sin espacios. Ej: `">  wall"` → modo `system`, query `wall`.

Al abrirse (`onLauncherVisibleChanged`): limpia búsqueda, limpia archivos, refresca clipboard y menús vivos, pone el foco en el cuadro de texto.

`goSection(id)` = "entra en una sección del menú sistema" (pone `">"`, refresca y enfoca).

### 3.3. Qué pasa al pulsar Enter (`activateItem`)

Cada resultado lleva un `kind`. Según eso:

* `app` → `entry.execute()` (o en terminal si lo pide el `.desktop`).
* `system` → si es submenú (`isSubmenu`), **no cierra**, navega con `goSection`; si no, ejecuta `shell` con `sh -c` (todas las hojas son `shell`/`ipc`: la base es genérica).
* `emoji` / `calc` → `printf ... | wl-copy` (copia al portapapeles). En
  emoji la copia la hace `EmojiService.copy()` (que además registra el uso
  en Recientes).
* `clip` → `ClipboardService.copyEntry(cid, isImage)`.
* `file` → comprueba que existe y `xdg-open <ruta>`; si desapareció o no se puede abrir, notificación.
* `web` → `xdg-open <url>`.

Todo lo largo se lanza con `Quickshell.execDetached` (desacoplado): el launcher se puede cerrar sin matar la app abierta.

### 3.4. De dónde sale `results` (una función por menú)

```qml
property var results: {
  if (m==="system") return systemResults(q);
  if (m==="emoji")  return emojiResults(q);
  ...
  return todoResults(q);
}
```

* `todoResults`: todas las apps si `q==""`, si no filtro difuso por nombre/comentario/id.
* `systemResults`: si `q==""` → `sectionItems(menuSection)` (navegación por secciones estilo Omarchy, con botón "Atrás"). Si hay query → búsqueda global en `systemPool()` (todo el sistema aplanado).
* `emojiResults`: delega en `EmojiService.queryItems(q)` (ver §9, sin
  tope: devuelve todos). Encima hay chips de categoría (grupos + Recientes
  + Favoritos, en Flow adaptable que salta de línea solo) que alternan el
  filtro `g:<grupo>`.
  `Ctrl+Mayús+F` marca/desmarca favorito sobre la selección.
* `clipResults`: foto (`snapshot`) del `ClipboardService`, filtro por título.
* `fileResultsList`: convierte `fileSnapshot` (llenado por `fd`) en items con icono/media, y pone primero lo que **empieza** por lo escrito.
* `calcResults`: solo muestra el resultado si es "fresco" (`calcForQuery===q`). Si no, "Calculando…" o "Escribe una operación".
* `webResults`: si parece URL (`isUrl`), ofrece "Abrir URL"; siempre ofrece "Buscar en DuckDuckGo".

Cada item tiene forma común: `{ kind, title, sub, iconName/appIcon/ch/imagePath, cat, ...datos propios }`. Eso permite que **un solo delegate** pinte todo.

### 3.5. Archivos con `fd` y calculadora con `qalc`

* Archivos: `fdCommand(home, query)` construye `["fd", "--type", "f", --exclude ..., ...]`. Sin query busca visibles con `"."` (truco: `fd` sin patrón no devuelve nada), con query busca en literal (`--fixed-strings`, `--hidden`, tope 100). Un `Timer` de 250 ms (debounce) evita lanzar `fd` a cada letra. La salida entra por streaming a `fileResults` (tope 200) y al terminar se congela en `fileSnapshot` para no romper bindings.
* Calc: `looksLikeCalc(q)` exige dígito + caracteres plausibles. Otro debounce de 250 ms lanza `["env","LC_ALL=C","qalc","-t", expr]` (coma → punto). La salida se acumula en `calcAcc` y al salir se guarda en `calcResult`.

### 3.6. Preview lateral (panel derecho)

`updatePreview(item)` + `hasLivePreview` + `hasTextPreview`:

* Solo pide preview si `MenuModes.supportsPreview + needsPreview` lo permiten.
* La petición va diferida (`schedulePreview` + `previewDebounce` 120 ms): moverse
  rápido solo genera el preview donde se asienta la selección; salir a un item
  sin preview limpia al instante (el panel no se retrasa).
* `clip` imagen → `ClipboardService.previewImage(cid)` (ruta temporal).
* `file` audio/video/pdf → `FilePreviewService.request(path, media)` (mata lo obsoleto).
* `file` texto → `FilePreviewService.requestText(path)` (primeros 6000 bytes, tope 200 KB; mata lo obsoleto).
* Si ya es el mismo item, no recarga (evita parpadeo).

En QML el `previewPanel.hasPreview` decide el ancho (600 vs 900) y qué mostrar: `Image` (miniatura), bloque de texto monoespaciado con scroll, o icono/emoji grande.

### 3.7. Interfaz (UI) de arriba a abajo

1. `MaterialTextField` (buscador) con `placeholder` distinto por modo + atajos: `Ctrl+J/N` abajo, `Ctrl+K/P` arriba, `↑/↓` moverse, `Tab/Shift+Tab` rotar de menú (`cycleMode`), `Backspace` en sistema vacío = subir de sección, `Supr` en clip = borrar entrada, `Enter` activar, `Esc` cerrar.
2. Fila de chips (pestañas) con scroll horizontal: `[>] Sistema  [/] Archivos ...`. Clic = cambiar de menú.
3. Breadcrumb (miga de pan) solo en `system`: `Sistema › Apariencia › Tema Fastfetch`. Clic = saltar.
4. `ListView` de resultados (56px por fila: icono + título + `cat · sub`). Hover = selecciona. Estado vacío: "Sin resultados" / "Portapapeles vacío" / "Cargando aplicaciones…".
5. Panel preview (si `hasPreview`).
6. Barra de ayuda: `Enter ejecutar · Tab cambia de modo · ...`.

---

## 4. `SystemMenuRegistry.qml` — el que junta todo lo del menú `>`

Es un `Singleton`. No pinta nada, solo **responde preguntas**: "¿qué secciones hay?", "¿qué items tiene X?", "¿qué coincide con esta búsqueda?".

Vía única (el display no distingue nada):

* **Providers unificados** vía `MenuStore.sectionInfos()`: `MenuProviders/System/*.qml`
  (internos, cargan primero) + tus `MenuProviders/*.qml` (ver §6). Estáticos y dinámicos
  llegan igual: los dinámicos regeneran `entries` en `refresh()`. Si tu `sectionId` choca
  con uno interno, **gana el interno** y sale aviso en consola.

(No existe una vía clásica `.js`: los antiguos `SystemMenu/*.js` se
eliminaron, y el antiguo `SystemMenuService` también: los dinámicos
`powerprofiles/fastfetch/animations` hoy son providers `MenuDefinition` en
`MenuProviders/System/`. Todo menú es un provider.)

Funciones importantes:

* `sections()` → lista única con títulos ya traducidos (`I18nService`).
* `sectionInfo(id)` / `trail(id)` → info y breadcrumb (subiendo por `parentId`).
* `staticEntries(id)` → `entries` crudas del provider tal cual (estático o dinámico).
* `sectionResultItems(id)` → **vía única para navegar**: items de esa sección.
* `systemSearchPool()` → **vía única para buscar**: todo aplanado con `cat` = nombre de sección.
* `refreshSection(id)` / `refreshAll()` → reenvían a `MenuStore` (no-op en estáticos).
* `toResultItem(entry, label)` → traduce `entry` semántica a item pintable (`previewPath` se convierte en `imagePath`).
* `shellOf(entry)` → `qs ipc call X` si `kind=="ipc"`, el `shellCommand` si `kind=="shell"`, `""` si `section`/`power`.

> Si entiendes esto, entiendes por qué el display (`AppLauncher`) no distingue orígenes: siempre llama al Registry.

---

## 5. `MenuProviders/System/*.qml` — las secciones internas (estáticas + dinámicas)

Son providers con el componente base (`Launcher/MenuDefinition.qml`, misma API que los tuyos):
`sectionId/titleFallback/titleKey/iconName/parentId/entries/refresh()`.

Cada entrada se escribe con las fábricas del componente:

```qml
shell("shot-region", "Capturar región", "hyprshot region", "crop",
  "sleep 0.5 && hyprshot -m region",
  { titleKey: "sysmenu.shot-region_t", subtitleKey: "sysmenu.shot-region_s" })
  // o ipc("keys", "Atajos", "ver cheatsheet", "keyboard", "cheatsheet toggle")
  // o submenu("cfg", "Configuración", "...", "settings", "configure")
```

* `titleFallback/subtitleFallback` = texto en español si no hay traducción (`opts.titleKey/subtitleKey` = claves `I18nService`).
* `iconName` = icono Material Symbols (¡debe existir o se ve roto!).
* `shell` ejecuta comando, `ipc` llama a otra parte del shell, `submenu` navega a otra sección.
  No hay más fábricas a propósito: la base es genérica y todo lo específico
  (energía, fastfetch, animaciones…) vive en su propio archivo.

Contenido actual (7 estáticos + 3 dinámicos, todos `MenuDefinition`):

Estáticos (`entries` fijas):

* `MainMenu.qml` (`main`, padre `""`): la raíz. Sobre el sistema, Actualizar, Atajos, Captura→`screenshot`, Configuración→`configure`, Apariencia→`appearance`, Juegos→`games`, Setup→`setup`, Power (`wlogout`), Bloquear.
* `ScreenshotMenu.qml` (`screenshot` ← `main`): 6 variantes `hyprshot` + anotar con `grim|satty` + `hyprpicker`.
* `ConfigureMenu.qml` (`configure` ← `main`): editar keybinds/permisos/monitores con emacs, DNS, energía→`powerprofiles`, paquetes→`packages`, setup→`setup`, ajustes y dashboard por IPC.
* `AppearanceMenu.qml` (`appearance` ← `main`): wallpapers por IPC, fastfetch→`fastfetch`, animaciones→`animations`.
* `PackagesMenu.qml` (`packages` ← `configure`): installer/uninstaller en terminal flotante.
* `SetupMenu.qml` (`setup` ← `main`): `docker-setup.sh`, `python-setup.sh` en kitty flotante.
* `GamesMenu.qml` (`games` ← `main`): `steam-setup`, `cartridges`.

Dinámicos (`entries` generadas en `refresh()`, reasignando el array entero,
con sus `Process` en `helpers` porque la raíz es `QtObject` y no admite hijos directos):

* `PowerProfilesMenu.qml` (`powerprofiles` ← `configure`): lee `PowerProfiles.profile`
  para marcar el activo con el badge `● Actual`. Si tu PC no tiene perfil Rendimiento,
  lo oculta. Genera `shell()` con `powerprofilesctl set ...`.
* `FastfetchMenu.qml` (`fastfetch` ← `appearance`): lista `~/.config/fastfetch/layouts/*`,
  detecta el actual con `readlink .../config.jsonc`, busca `previews/<nombre>.png` para el
  preview lateral, y genera `shell()` con `ln -sf ... && notify-send ...`.
* `AnimationsMenu.qml` (`animations` ← `appearance`): lista
  `~/.config/hypr/configs/animations/*.lua`, detecta la actual con `grep require(`, y genera
  `shell()` con `sed ... && hyprctl reload && notify-send ...`. El `sed` solo se ejecuta
  al pulsar `Enter` en una entrada, nunca solo.

Patrón anti-loops (el que usan los 3 dinámicos): el `Process` acumula en `_found/_current`
y solo al terminar (`onExited`) reasigna `entries` entero. Nunca `push` parcial a `entries`.

Para editar uno: toca el `.qml` y se aplica al abrir el launcher (comprueba cambios en disco). O fuerza con `qs ipc call launcher reloadMenus`.

---

## 6. Menús personalizados — la parte estrella ⭐

Hay **una sola forma**: providers (ver §5 para el formato de entradas).

### 6.1. Arquitectura: `MenuStore.qml` + `MenuDefinition.qml`

* `Launcher/MenuDefinition.qml` es el **componente base genérico** (módulo `qs.Launcher`).
  No es un menú ni sabe nada de ninguno: solo el contrato
  (`sectionId/titleFallback/titleKey/iconName/parentId/entries/helpers/refresh()`)
  + fábricas `shell()/ipc()/submenu()/entry()`. Toda la lógica vive en cada archivo.
* `MenuStore.qml` es un detective: al arrancar ejecuta un `sh` que lista `MenuProviders/System/*.qml` + `MenuProviders/*.qml`, los carga con `Qt.createComponent`, los instancia y guarda la lista en `providers` (internos primero). Al abrir el launcher se firman los ficheros y se recarga solo si cambiaron (sin proceso periódico).
* Reglas: si el archivo no carga → aviso y se salta. Si no expone `sectionId` → se ignora. Si el `sectionId` choca con uno interno → gana el interno.
* `sectionInfos()` / `entriesOf(id)` / `providerFor(id)` exponen tus menús al Registry.
* `refreshSection(id)` / `refreshAll()` llaman a tu `refresh()` (en menús fijos es vacío, no pasa nada).

> Resultado: **añadir un menú = soltar un archivo (se aplica al abrir el launcher). Quitarlo = borrarlo.** Sin tocar Registry ni servicios. `qs ipc call launcher reloadMenus` fuerza la recarga inmediata.

### 6.2. El contrato: tu archivo es un `MenuDefinition`

Ejecuta `MenuProviders/new-menu.sh MiMenu "Mi menú"` (o escribe el archivo a mano en `MenuProviders/` con `import qs.Launcher`):

```qml
import qs.Launcher
MenuDefinition {
  sectionId: "mimenu"             // ÚNICO, sin espacios. Ej: "notas", "trabajo"
  titleFallback: "Mi menú"        // Nombre visible
  titleKey: ""                    // "" = usa el fallback (recomendado para empezar)
  iconName: "menu"                // Material Symbol válido
  parentId: "main"                // ¿De quién cuelga? "main" = aparece en Sistema
  entries: [ ... ]                // Tus botones con shell()/ipc()/submenu()
  // function refresh() {}       // Solo si es dinámico: heredado no-op (ver 6.5)
}
```
> Asigna a secas: NO pongas `property` delante (redeclarar rompe el menú).

Fábricas (todas aceptan `opts` opcional `{titleKey, subtitleKey, preview}`):

```qml
shell("abrir-notas", "Abrir notas", "carpeta ~/Notas", "folder", "xdg-open ~/Notas")
ipc("atajos", "Atajos", "ver cheatsheet", "keyboard", "cheatsheet toggle")
submenu("cliente", "Cliente X", "submenú", "arrow_forward", "cliente-x")
entry("tema", "Tema oscuro", "ver preview", "palette",
  { kind: "shell", shellCommand: "notify-send 'Tema' 'oscuro'" },
  { preview: "/home/tu/.config/fastfetch/previews/oscuro.png" })
```

| Fábrica | Qué hace |
|---|---|
| `shell(id, título, sub, icono, cmd, opts)` | Ejecuta en `sh -c`. Para apps, scripts, `notify-send`, etc. |
| `ipc(id, título, sub, icono, call, opts)` | Ejecuta `qs ipc call ...`. Para hablar con el propio shell. |
| `submenu(id, título, sub, icono, sección, opts)` | Navega a otra sección (tuya o interna). No cierra el menú. |
| `entry(id, título, sub, icono, action, opts)` | Control total con `action` cruda (`shell`/`ipc`/`section`). |

`opts.preview` con imagen existente → preview en el panel derecho (modo `>`). `titleKey/subtitleKey` para i18n (si no, literales en español).

### 6.3. Ejemplo 1 — menú estático (5 minutos, copiar-pegar)

Objetivo: un menú "Proyectos" colgado de Sistema con 3 acciones.

Crea `Launcher/MenuProviders/Proyectos.qml`:

```qml
import qs.Launcher
MenuDefinition {
  sectionId: "proyectos"
  titleFallback: "Proyectos"
  iconName: "folder"
  parentId: "main"
  entries: [
    shell("web", "Abrir web", "mi portafolio", "open_in_new", "xdg-open https://ejemplo.com"),
    shell("carpeta", "Abrir carpeta", "~/Proyectos", "folder", "xdg-open ~/Proyectos"),
    shell("editar", "Editar en Emacs", "emacsclient", "edit", "emacsclient -c -a emacs ~/Proyectos")
  ]
}
```

Se aplica al abrir el launcher (comprueba cambios en disco). Abre con `>` (sistema), entra en `Proyectos`. También lo encontrarás escribiendo `> proy`.

Para que tenga sub-niveles, crea otro provider con `parentId: "proyectos"` y una entrada que apunte a él:

```qml
// en Proyectos.qml, añade:
submenu("ver-cliente", "Cliente X", "submenú", "arrow_forward", "cliente-x")
```

```qml
// en ClienteX.qml:
import qs.Launcher
MenuDefinition {
  sectionId: "cliente-x"
  titleFallback: "Cliente X"
  ...
  parentId: "proyectos"
  ...
}
```

El breadcrumb mostrará `Sistema › Proyectos › Cliente X` solo.

### 6.4. Ejemplo 2 — con preview de imagen

```qml
entries: [
  entry("tema-oscuro", "Tema oscuro", "ver preview", "palette",
    { kind: "shell", shellCommand: "notify-send 'Tema' 'oscuro aplicado'" },
    { preview: "/home/tu/.config/fastfetch/previews/oscuro.png" })
]
```

Si el PNG existe, al seleccionar verás la imagen a la derecha (el menú se ensancha a 900px solo).

### 6.5. Ejemplo 3 — menú dinámico (se genera al abrirse)

Objetivo: listar tus scripts `~/.local/bin/mis-*` como botones.

> Regla de oro: **reasigna `entries` entero al terminar, no lo mutes por partes** (`entries = nuevaLista`). Así QML se entera de golpe.

```qml
import qs.Launcher
import Quickshell
import Quickshell.Io
import "../../Base/ShellUtils.js" as ShellUtils
MenuDefinition {
  id: root
  sectionId: "scripts"
  titleFallback: "Mis scripts"
  iconName: "terminal"
  parentId: "main"
  entries: []

  // Escape común (misma implementación para todo Launcher).

  function refresh() {
    // Se llama al abrir el launcher y al entrar en la sección.
    // Aquí lanzamos un proceso que lista scripts; al terminar, rellenamos entries.
    if (listProc.running)
      return;
    listProc.command = ["sh", "-c", "ls -1 ~/.local/bin/mis-* 2>/dev/null"];
    listProc.running = true;
  }

  property var _found: []
  // OJO: el Process va en `helpers`, no como hijo directo: la raíz es un
  // QtObject y QML rechaza hijos declarativos en él
  // ("Cannot assign to non-existent default property").
  helpers: [ Process {
    id: listProc
    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (line !== "") root._found.push(line);
      }
    }
    onRunningChanged: { if (running) root._found = []; }
    onExited: {
      const out = [];
      for (let i = 0; i < root._found.length; i++) {
        const name = root._found[i].split("/").pop();
        out.push(root.shell("script-" + name, name, "ejecutar script", "terminal",
          "xdg-terminal-exec -e '" + ShellUtils.shellEscape(root._found[i]) + "'"));
      }
      root.entries = out; // ← reasignación entera
    }
  } ]
}
```

*Nota: adapta el `command` antes de `running=true`. El patrón de arriba (acumular en `_found` y volcar en `onExited`) es el mismo que usan `FastfetchMenu/AnimationsMenu` y `FilePreviewService`.*

### 6.6. Errores típicos de principiantes

1. **`sectionId` duplicado o con espacios** → usa minúsculas-guiones (`"mis-notas"`). Si choca con `main/screenshot/configure/...`, se ignora el tuyo.
2. **Icono roto (círculo vacío)** → `iconName` debe existir en Material Symbols (`folder`, `terminal`, `palette`, `menu`...). Prueba con `menu` si dudas.
3. **No aparece** → ¿el archivo está en `MenuProviders/` y no se llama `MenuDefinition.qml`? Abre de nuevo el launcher (comprueba cambios en disco) o fuerza con `qs ipc call launcher reloadMenus`. Mira la consola: `MenuStore: ...` te dice qué falló.
4. **Comillas rotas en `shellCommand`** → si tu ruta tiene `'`, escápala. Usa comillas dobles fuera y simples dentro, o la función `shEscape` del ejemplo.
5. **Mutar `entries` con `push`** → no se refresca bien. Siempre `entries = nuevaLista`.
6. **Badge vivo + `subtitleKey`** → si el subtítulo lleva estado (ej. `● Actual`),
   NO pases `subtitleKey`: el Registry prefiere la clave y la traduce pelada,
   perdiendo el badge. Deja el texto ya compuesto en el fallback (el idioma se
   mantiene con `langWatch → refresh()`).
7. **Esperar preview en `todo/@/./=/ :`** → el preview propio solo funciona en modo `>` (`system`). Es por diseño (`MenuModes.needsPreview`).

---

## 7. Menús dinámicos internos — ya son `MenuDefinition` (sin servicio aparte)

No hay servicio de "datos vivos": las 3 secciones que cambian solas son providers
dinámicos en `MenuProviders/System/` (ver §5). Cada uno implementa `refresh()` y
reasigna `entries` entero al terminar; `SystemMenuRegistry.refreshSection/refreshAll()`
simplemente llama a ese `refresh()` (no-op en los estáticos).

* `powerprofiles`: D-Bus nativo + `power()` + badge `● Actual`.
* `fastfetch`: `Process` + `shell()` + `opts.preview` con PNG.
* `animations`: `Process` + `shell()` con `sed + hyprctl reload`.

Si creas un provider dinámico, imita ese patrón (`FastfetchMenu.qml` es el ejemplo
a copiar: `_found/_current` + `onExited: root.entries = out`).

---

## 8. `FilePreviewService.qml` — miniaturas bajo demanda

Solo para modo `/` (archivos). Las imágenes se muestran directas, el resto pasa por aquí:

* `audio` → carátula con `ffmpeg -vcodec mjpeg`.
* `video` → fotograma con `ffmpegthumbnailer -s 512`.
* `pdf` → primera página con `pdftoppm -png -r 100`.
* `texto` → `requestText`: `head -c 6000`, tope 200 KB (`QSTEXT_TOO_BIG` si se pasa).

Caché en `/tmp/qs-filepreview/<sha16>.jpg|.png` (clave = ruta+mtime+tamaño, tope 60 ficheros, se podan los viejos). El shell imprime `QSOUT:<ruta>` y el servicio emite `ready(path,image)` / `textReady(path,text)`. Si pides otra cosa mientras trabaja, mata lo en curso y solo gana la última (nada en paralelo).

---

## 9. Emojis — generados en runtime por un programa (nada hardcodeado)

El modo `.` lo sirve **`EmojiService.qml`** (Singleton en `Launcher/`).
El catálogo NO vive en ningún `.js`: al arrancar, el servicio ejecuta UN
solo proceso `python3 scripts/emoji-dump.py --all` (la versión de la
librería viene en la cabecera `#VERSION`, sin segundo proceso) y consume
su salida TSV (`CH \t NOMBRE \t GRUPO \t KEYWORDS`) línea a línea vía
`Process` + `SplitParser`. Fuentes del programa:

* emojis: librería `emoji` de PyPI (`EMOJI_DATA`, solo fully-qualified,
  sin tonos de piel). `pip install emoji` (ya es dependencia del shell).
* símbolos: stdlib `unicodedata` (flechas, operadores mates, moneda,
  formas, dingbats), elegidos por bloque Unicode + patrones de nombre
  en el propio script. Sin caracteres hardcodeados.
* grupo amplio por clasificador (`caras/gente/cosas/simbolos`) y keywords
  con variantes morfológicas (`smile`↔`smiling`, `heart`↔`hearts`) más
  sinónimos (`#SYN`: sirven al indexar y al expandir tu consulta),
  todo en el script, en inglés siempre (mezclar idiomas rompía el ranking).

Encima solo va tu `EmojiCustom.js` (tu config, prioridad máxima; si un
`ch` tuyo coincide con uno generado, manda el tuyo). `sourceInfo()`
resume el estado (`custom/lib/symbols/status/total`).

Si la librería `emoji` no está instalada, el proceso falla y el picker
sigue funcionando con tus custom + símbolos stdlib (avisa por consola).

Búsqueda con ranking propio (nombre exacto > palabra exacta > prefijo de
nombre > prefijo de keyword > contiene, con boost de favoritos/recientes
y de lo tuyo sobre lo generado, SIN tope: devuelve todas las
coincidencias). Las keywords traen variantes morfológicas
(`smile`↔`smiling`, `heart`↔`hearts`) y los `#SYN` del script expanden la
consulta (`lol`→`laugh`/`joy`, `tux`→`penguin`), así el ruido por
subcadena (`lollipop`, `joystick`) queda debajo. Filtro por grupo:
`. g:cosas game` o `. group:simbolos arrow` (valen alias antiguos como
`g:tech` y acentos como `g:símbolos`). Vista vacía: recientes
primero y luego todo lo generado (caras delante, símbolos al final).

Recientes + favoritos persistidos en `~/.local/state/quickshell/emoji.json`
(vía FileView, como `Persistent.qml`, mismo debounce de 100 ms). Editar
`EmojiCustom.js` lo detecta otro FileView (sin `stat` periódico) y se
reaplica al momento.
El modo emoji NO usa preview lateral (`previewMode: "never"`): la lista
ocupa todo el ancho y cada fila ya muestra carácter + nombre + keywords.

---

## 10. Flujo completo (para fijar ideas)

1. Pulsas atajo → `qs ipc call launcher openSystem` → `forcedMode="system"`, `menuSection="main"`, `launcherVisible=true`.
2. Al abrir: `refreshAll()` (llama al `refresh()` de todos los providers; no-op en los estáticos; con guarda de 8 s si acabas de abrirlo), foco en buscador con `">"`. Entrar en una sección (`refreshSection`) es siempre fresco.
3. Escribes `> ani` → `activeMode="system"`, `query="ani"` → `systemResults` filtra `systemSearchPool()` → ves "Animaciones Hyprland".
4. `Enter` en un `isSubmenu` → `goSection("animations")` → `refreshSection` → lista dinámica + preview si hay PNG.
5. `Enter` en hoja → `runShell(entry.shell)` → `launcherVisible=false` (p. ej. `powerprofilesctl set balanced`).

Abrir `/home` y previsualizar un PDF: modo `files`, `fd` llena `fileSnapshot`, seleccionas el PDF → `FilePreviewService.request` → `ready` → imagen a la derecha.

---

## 11. Chuleta rápida

| Quiero... | Toco... |
|---|---|
| Cambiar prefijos/modos base | `MenuModes.js` (`defs`) |
| Cambiar ventana/lista/preview/atajos | `AppLauncher.qml` |
| Añadir/editar sección interna | `MenuProviders/System/*.qml` (se aplica al abrir el launcher) |
| Añadir sección dinámica interna | `MenuProviders/System/NuevoDinamico.qml` (`MenuDefinition` + `refresh()`; copia `FastfetchMenu.qml`) |
| **Crear MI menú (recomendado)** | **`./new-menu.sh X "Título"` o `MenuDefinition { }` a mano (se aplica al abrir)** |
| Miniaturas audio/video/pdf/texto | `FilePreviewService.qml` |
| Más emojis / símbolos | `EmojiCustom.js` (tuyos, manda sobre lo generado) |
| Cómo se genera el catálogo emoji | `scripts/emoji-dump.py --all` (runtime, sin .js de datos) |
| Escape shell en comandos `sh -c` | `ShellUtils.shellEscape` (única implementación en Launcher) |
| Copiar texto al portapapeles | `ClipboardService.copyText` (vía única) |
| Traducciones | claves `titleKey/subtitleKey` + `I18nService` |

Tras crear/editar/borrar un `MenuProviders/*.qml` no hay que hacer nada: se aplica al abrir el launcher (o fuerza con `qs ipc call launcher reloadMenus`).

---

*Fin. Si solo te quedas con una frase: **para un menú propio, escribe un `MenuDefinition { }` con `sectionId` único y `entries` con `shell()/ipc()/submenu()`: se aplica al abrir el launcher.***
