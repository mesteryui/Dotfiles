# Launcher / Quickshell — Guía completa de funcionamiento y creación de menús

> Para alguien que apenas sabe programar. Extensa, pero sin rodeos.

## 0. La idea en 30 segundos

`Launcher/` es **una ventanita buscadora** que se abre con el teclado (estilo Walker / Elephant / Rofi / Spotlight).

Tú escribes, él filtra, pulsas `Enter` y ejecuta algo: abrir una app, copiar un emoji, pegar del portapapeles, abrir un archivo, calcular `45*1.21`, buscar en la web o tocar un ajuste del sistema.

Analogía de restaurante:

* **AppLauncher.qml** = el camarero y el local (lo que ves y lo que hace al pulsar).
* **MenuModes.js** = la carta dividida en secciones (menús).
* **SystemMenuRegistry.qml** = el jefe de cocina que junta todas las recetas.
* **MenuProviders/System/*.qml** = recetas fijas internas (misma interfaz que las tuyas).
* **MenuProviders/*.qml (tus archivos)** = TUS menús. Todo unificado bajo `MenuProviders/`.
* **SystemMenuService.qml** = cocina en vivo (mira qué hay *ahora mismo* en tu PC).
* **CustomMenuService.qml (UnifiedMenuStore) + MenuProviders/*.qml** = SISTEMA ÚNICO: aquí creas **tus propios menús** sin tocar lo demás. Los internos usan la misma interfaz.
* **MenuProviders/new-menu.sh** = generador: `new-menu.sh MiMenu "Mi menú"` crea el archivo por ti.
* **FilePreviewService.qml** = el fotógrafo que hace miniaturas.
* **EmojiData.js / EmojiFull.js** = dos diccionarios de emojis.

Todo vive en:

```
~/.config/quickshell/Launcher/
├── AppLauncher.qml          # ventana + lógica + interfaz
├── MenuModes.js             # qué menús existen y con qué letra se activan
├── SystemMenuRegistry.qml   # une menús fijos + vivos + tuyos
├── SystemMenuService.qml    # datos vivos: energía, fastfetch, animaciones
├── CustomMenuService.qml    # descubre tus menús automáticamente
├── FilePreviewService.qml   # miniaturas de archivos
├── EmojiData.js             # ~120 emojis curados en español
├── EmojiFull.js             # miles de emojis en inglés (respaldo)
├── MenuProviders/           # SISTEMA ÚNICO (todo aquí dentro)
│   ├── MenuProvider.qml     # PLANTILLA del sistema único
│   ├── new-menu.sh          # generador: ./new-menu.sh MiMenu "Mi menú"
│   ├── System/              # 7 internos (misma interfaz que los tuyos)
│   └── MiMenu.qml           # tus menús (uno por archivo, al lado de System/)
└── SystemMenu/
    └── *.js                 # LEGADO solo referencia (el Registry ya no los usa)
```

---

## 1. Conceptos mínimos para entender el código

Si nunca programaste en QML/JS, quédate con esto:

| Concepto | Qué es, en cristiano |
|---|---|
| `QML` (`.qml`) | Lenguaje para describir ventanas. Mezcla "cómo se ve" (botones, listas) con "qué hace" (funciones). |
| `JS` (`.js`) | Lógica pura: listas, textos, funciones. Sin ventana. |
| `property` | Una variable guardada en la ventana. Ej: `property string query` = "lo que has escrito sin el prefijo". Si cambia, todo lo que depende de ella se recalcula solo. |
| `function` | Una receta: le das ingredientes, te devuelve algo o hace algo. |
| `Singleton` | Un objeto único en todo el programa. `CustomMenuService` hay uno solo, todos le preguntan a él. |
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
| `emoji` | `.` | Emojis/símbolos → `wl-copy` | nunca |
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
qs ipc call launcher openFiles "doc"
qs ipc call launcher search "> wall"
```

`toggleMode(name)` es la lógica de "si ya estoy en ese menú, cierro; si no, abro".

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
* `system` → si es `nativeApply=="power"`, cambia perfil nativo; si es submenú (`isSubmenu`), **no cierra**, navega con `goSection`; si no, ejecuta `shell` con `sh -c`.
* `emoji` / `calc` → `printf ... | wl-copy` (copia al portapapeles).
* `clip` → `ClipboardService.copyEntry(cid, isImage)`.
* `file` → `xdg-open <ruta>`.
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
* `emojiResults`: junta curados + full (sin repetir por `ch`), top 60.
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
* `clip` imagen → `ClipboardService.previewImage(cid)` (ruta temporal).
* `file` audio/video/pdf → `FilePreviewService.request(path, media)`.
* `file` texto → `FilePreviewService.requestText(path)` (primeros 6000 bytes, tope 200 KB).
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

Tres orígenes:

1. **Estáticos**: `staticModules = [Main, Screenshot, Configure, Appearance, Packages, Setup, Games]` (los `.js`).
2. **Dinámicos internos**: `dynamicInfo = [powerprofiles, fastfetch, animations]` (datos vivos de `SystemMenuService`).
3. **Tuyos**: `CustomMenuService.sectionInfos()` (ver §6). Si tu `sectionId` choca con uno interno, **gana el interno** y sale aviso en consola.

Funciones importantes:

* `sections()` → lista única con títulos ya traducidos (`I18nService`).
* `sectionInfo(id)` / `trail(id)` → info y breadcrumb (subiendo por `parentId`).
* `staticEntries(id)` → `entries()` crudas del `.js`.
* `builtinDynamicItems(id, withCat)` → convierte `dynSnapshot` en items pintables (`nativeApply` para energía, `shellFor` para el resto, `imagePath` con `file://` para previews fastfetch).
* `sectionResultItems(id)` → **vía única para navegar**: estáticos + dinámicos + tuyos de esa sección.
* `systemSearchPool()` → **vía única para buscar**: todo aplanado con `cat` = nombre de sección.
* `refreshSection(id)` / `refreshAll()` → reenvían a `SystemMenuService` + `CustomMenuService`.
* `toResultItem(entry, label)` → traduce `entry` semántica a item pintable. Aquí el enlace a `powerprofiles` añade `" · Equilibrado/Actual..."` al subtítulo, y `previewPath` se convierte en `imagePath`.
* `shellOf(entry)` → `qs ipc call X` si `kind=="ipc"`, o el `shellCommand` si `kind=="shell"`.

> Si entiendes esto, entiendes por qué el display (`AppLauncher`) no distingue orígenes: siempre llama al Registry.

---

## 5. `SystemMenu/*.js` — las secciones fijas (vía clásica)

Cada archivo es una librería (`.pragma library`) con dos funciones:

```js
function info() { return { sectionId:"...", titleFallback:"...", titleKey:"...", iconName:"...", parentId:"..." }; }
function entries() { return [ {...}, {...} ]; }
```

Cada entrada:

```js
{
  entryId: "shot-region",
  titleFallback: "Capturar región", titleKey: "sysmenu.shot-region_t",
  subtitleFallback: "hyprshot region", subtitleKey: "sysmenu.shot-region_s",
  iconName: "crop",
  action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m region" }
  // o { kind: "ipc", ipcCall: "cheatsheet toggle" }
  // o { kind: "section", targetSectionId: "screenshot" }
}
```

* `titleFallback/subtitleFallback` = texto en español si no hay traducción.
* `titleKey/subtitleKey` = clave de `I18nService` para otros idiomas (puede ser `""`).
* `iconName` = icono Material Symbols (¡debe existir o se ve roto!).
* `action.kind`: `shell` ejecuta comando, `ipc` llama a otra parte del shell, `section` navega a otra sección.

Contenido actual:

* `Main.js` (`main`, padre `""`): la raíz. Sobre el sistema, Actualizar, Atajos, Captura→`screenshot`, Configuración→`configure`, Apariencia→`appearance`, Juegos→`games`, Setup→`setup`, Power (`wlogout`), Bloquear.
* `Screenshot.js` (`screenshot` ← `main`): 6 variantes `hyprshot` + anotar con `grim|satty` + `hyprpicker`.
* `Configure.js` (`configure` ← `main`): editar keybinds/permisos/monitores con emacs, DNS, energía→`powerprofiles`, paquetes→`packages`, setup→`setup`, ajustes y dashboard por IPC.
* `Appearance.js` (`appearance` ← `main`): wallpapers por IPC, fastfetch→`fastfetch`, animaciones→`animations`.
* `Packages.js` (`packages` ← `configure`): installer/uninstaller en terminal flotante.
* `Setup.js` (`setup` ← `main`): `docker-setup.sh`, `python-setup.sh` en kitty flotante.
* `Games.js` (`games` ← `main`): `steam-setup`, `cartridges`.

**Añadir una sección clásica**: crea `SystemMenu/MiSeccion.js`, impórtala arriba del Registry y añádela a `staticModules`. Funciona, pero la vía recomendada hoy es la de abajo (no tocas el Registry).

---

## 6. Menús personalizados — la parte estrella ⭐

Hay **dos formas**. La recomendada es la **vía libre** (providers). La clásica (`.js` + Registry) ya la viste arriba.

### 6.1. Arquitectura: `CustomMenuService.qml` + `MenuProvider.qml`

* `MenuProviders/MenuProvider.qml` es una **plantilla**. No hace nada por sí sola, es para copiar.
* `CustomMenuService.qml` es un detective: al arrancar ejecuta un `sh` que lista `MenuProviders/*.qml` (menos `MenuProvider.qml`), los carga con `Qt.createComponent`, los instancia y guarda la lista en `providers`.
* Reglas: si el archivo no carga → aviso y se salta. Si no expone `sectionId` → se ignora. Si el `sectionId` choca con uno interno → gana el interno.
* `sectionInfos()` / `entriesOf(id)` / `providerFor(id)` exponen tus menús al Registry.
* `refreshSection(id)` / `refreshAll()` llaman a tu `refresh()` (en menús fijos es vacío, no pasa nada).

> Resultado: **añadir un menú = soltar un archivo y recargar el shell. Quitarlo = borrarlo.** Sin tocar Registry ni servicios.

### 6.2. El contrato: qué debe exponer tu archivo

Copia `MenuProvider.qml` a `MenuProviders/MiMenu.qml` y rellena:

```qml
import QtQuick
QtObject {
  property string sectionId: "mimenu"       // ÚNICO, sin espacios. Ej: "notas", "trabajo"
  property string titleFallback: "Mi menú"  // Nombre visible
  property string titleKey: ""              // "" = usa el fallback (recomendado para empezar)
  property string iconName: "menu"          // Material Symbol válido
  property string parentId: "main"          // ¿De quién cuelga? "main" = aparece en Sistema
  property var entries: [ ... ]             // Tus botones
  function refresh() {}                     // Solo si es dinámico (ver 6.5)
}
```

Cada item de `entries` usa el **mismo esquema que `SystemMenu/*.js`**, más un extra:

```qml
{
  entryId: "abrir-notas",
  titleFallback: "Abrir notas", titleKey: "",
  subtitleFallback: "carpeta ~/Notas", subtitleKey: "",
  iconName: "folder",
  action: { kind: "shell", shellCommand: "xdg-open ~/Notas" },
  previewPath: ""  // opcional: "/home/tu/foto.png" → preview lateral
}
```

Tipos de `action`:

| `kind` | Forma | Qué hace |
|---|---|---|
| `"shell"` | `{ kind:"shell", shellCommand:"..." }` | Ejecuta en `sh -c`. Para apps, scripts, `notify-send`, etc. |
| `"ipc"` | `{ kind:"ipc", ipcCall:"cheatsheet toggle" }` | Ejecuta `qs ipc call ...`. Para hablar con el propio shell. |
| `"section"` | `{ kind:"section", targetSectionId:"..." }` | Navega a otra sección (tuya o interna). No cierra el menú. |

`titleKey/subtitleKey` pueden ser `""` (usa el literal español). `previewPath` si es imagen existente → aparece en el panel derecho cuando estás en `>` y seleccionas ese item.

### 6.3. Ejemplo 1 — menú estático (5 minutos, copiar-pegar)

Objetivo: un menú "Proyectos" colgado de Sistema con 3 acciones.

Crea `Launcher/MenuProviders/Proyectos.qml`:

```qml
import QtQuick
QtObject {
  property string sectionId: "proyectos"
  property string titleFallback: "Proyectos"
  property string titleKey: ""
  property string iconName: "folder"
  property string parentId: "main"
  property var entries: [
    { entryId: "web", titleFallback: "Abrir web", titleKey: "", subtitleFallback: "mi portafolio", subtitleKey: "", iconName: "open_in_new",
      action: { kind: "shell", shellCommand: "xdg-open https://ejemplo.com" } },
    { entryId: "carpeta", titleFallback: "Abrir carpeta", titleKey: "", subtitleFallback: "~/Proyectos", subtitleKey: "", iconName: "folder",
      action: { kind: "shell", shellCommand: "xdg-open ~/Proyectos" } },
    { entryId: "editar", titleFallback: "Editar en Emacs", titleKey: "", subtitleFallback: "emacsclient", subtitleKey: "", iconName: "edit",
      action: { kind: "shell", shellCommand: "emacsclient -c -a emacs ~/Proyectos" } }
  ]
  function refresh() {}
}
```

Recarga el shell. Abre con `>` (sistema), entra en `Proyectos`. También lo encontrarás escribiendo `> proy`.

Para que tenga sub-niveles, crea otro provider con `parentId: "proyectos"` y una entrada que apunte a él:

```qml
// en Proyectos.qml, añade:
{ entryId: "ver-cliente", titleFallback: "Cliente X", titleKey: "", subtitleFallback: "submenú", subtitleKey: "", iconName: "arrow_forward",
  action: { kind: "section", targetSectionId: "cliente-x" } }
```

```qml
// en ClienteX.qml:
QtObject {
  property string sectionId: "cliente-x"
  property string titleFallback: "Cliente X"
  ...
  property string parentId: "proyectos"
  ...
}
```

El breadcrumb mostrará `Sistema › Proyectos › Cliente X` solo.

### 6.4. Ejemplo 2 — con preview de imagen

```qml
property var entries: [
  { entryId: "tema-oscuro", titleFallback: "Tema oscuro", titleKey: "", subtitleFallback: "ver preview", subtitleKey: "", iconName: "palette",
    action: { kind: "shell", shellCommand: "notify-send 'Tema' 'oscuro aplicado'" },
    previewPath: "/home/tu/.config/fastfetch/previews/oscuro.png" }
]
```

Si el PNG existe, al seleccionar verás la imagen a la derecha (el menú se ensancha a 900px solo).

### 6.5. Ejemplo 3 — menú dinámico (se genera al abrirse)

Objetivo: listar tus scripts `~/.local/bin/mis-*` como botones.

> Regla de oro: **reasigna `entries` entero al terminar, no lo mutes por partes** (`entries = nuevaLista`). Así QML se entera de golpe.

```qml
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
  id: root
  property string sectionId: "scripts"
  property string titleFallback: "Mis scripts"
  property string titleKey: ""
  property string iconName: "terminal"
  property string parentId: "main"
  property var entries: []

  function shEscape(s) { return String(s).replace(/'/g, "'\\''"); }

  function refresh() {
    // Se llama al abrir el launcher y al entrar en la sección.
    // Aquí lanzamos un proceso que lista scripts; al terminar, rellenamos entries.
    listProc.running = true;
  }

  property var _found: []
  Process {
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
        out.push({
          entryId: "script-" + name,
          titleFallback: name, titleKey: "",
          subtitleFallback: "ejecutar script", subtitleKey: "",
          iconName: "terminal",
          action: { kind: "shell", shellCommand: "xdg-terminal-exec -e '" + root.shEscape(root._found[i]) + "'" }
        });
      }
      root.entries = out; // ← reasignación entera
    }
  }
  Component.onCompleted: {
    // Comando inicial: lista una vez para que tenga algo si se busca globalmente
    listProc.command = ["sh", "-c", "ls -1 ~/.local/bin/mis-* 2>/dev/null"];
    listProc.command = ["sh", "-c", "ls -1 ~/.local/bin/mis-* 2>/dev/null"];
  }
}
```

*Nota: adapta el `command` antes de `running=true`. El patrón de arriba (acumular en `_found` y volcar en `onExited`) es el mismo que usan `SystemMenuService` y `FilePreviewService`.*

### 6.6. Errores típicos de principiantes

1. **`sectionId` duplicado o con espacios** → usa minúsculas-guiones (`"mis-notas"`). Si choca con `main/screenshot/configure/...`, se ignora el tuyo.
2. **Icono roto (círculo vacío)** → `iconName` debe existir en Material Symbols (`folder`, `terminal`, `palette`, `menu`...). Prueba con `menu` si dudas.
3. **No aparece** → ¿el archivo está en `MenuProviders/` y no se llama `MenuProvider.qml`? ¿Recargaste el shell? Mira la consola: `CustomMenuService: ...` te dice qué falló.
4. **Comillas rotas en `shellCommand`** → si tu ruta tiene `'`, escápala. Usa comillas dobles fuera y simples dentro, o la función `shEscape` del ejemplo.
5. **Mutar `entries` con `push`** → no se refresca bien. Siempre `entries = nuevaLista`.
6. **Esperar preview en `todo/@/./=/ :`** → el preview propio solo funciona en modo `>` (`system`). Es por diseño (`MenuModes.needsPreview`).

---

## 7. `SystemMenuService.qml` — datos vivos (dinámicos internos)

Tres secciones que **no están escritas en `.js`** porque cambian solas:

* `powerprofiles` (← `configure`):lee `PowerProfiles.profile` por D-Bus (nativo, reactivo). `applyPowerProfile(v)` lo cambia. Si tu PC no tiene perfil Rendimiento, lo oculta. El badge `● Actual` marca el activo.
* `fastfetch` (← `appearance`): lista `~/.config/fastfetch/layouts/*`, detecta el actual con `readlink .../config.jsonc`, busca `previews/<nombre>.png` para el preview, y `shellFor` genera `ln -sf ... && notify-send ...`.
* `animations` (← `appearance`): lista `~/.config/hypr/configs/animations/*.lua`, detecta la actual con `grep require(`, y `shellFor` hace `sed ... && hyprctl reload && notify-send ...`.

Patrón anti-loops: los `Process` escriben en `fastfetchModel/animModel` (ruidosos), pero al terminar se congela todo en `dynSnapshot` (silencioso). El Registry solo lee `dynSnapshot`. `powerSnapshot()` se reconstruye al cambiar idioma o perfil.

Si creas un provider dinámico, imita este patrón.

---

## 8. `FilePreviewService.qml` — miniaturas bajo demanda

Solo para modo `/` (archivos). Las imágenes se muestran directas, el resto pasa por aquí:

* `audio` → carátula con `ffmpeg -vcodec mjpeg`.
* `video` → fotograma con `ffmpegthumbnailer -s 512`.
* `pdf` → primera página con `pdftoppm -png -r 100`.
* `texto` → `requestText`: `head -c 6000`, tope 200 KB (`QSTEXT_TOO_BIG` si se pasa).

Caché en `/tmp/qs-filepreview/<sha16>.jpg|.png` (clave = ruta+mtime+tamaño, tope 60 ficheros, se podan los viejos). El shell imprime `QSOUT:<ruta>` y el servicio emite `ready(path,image)` / `textReady(path,text)`. Si pides otra cosa mientras trabaja, la encola como `pending` y solo gana la última.

---

## 9. `EmojiData.js` y `EmojiFull.js` — los dos diccionarios

Ambos exponen `getEmojis()` con `{ ch, name, kw }`:

* `EmojiData.js` (~120 líneas): curado a mano, **en español**. `name` + `kw` pensados para `FuzzySearch` (`{ ch:"😂", name:"risa llanto", kw:"laugh joy lol jaja" }`).
* `EmojiFull.js` (1 línea gigante): generado por script desde el paquete python `emoji`. Miles de emojis en inglés, sin tonos de piel, solo fully-qualified.

`AppLauncher.emojiResults` los junta (curados primero, sin duplicar `ch`) y corta a 60. Al activar, `wl-copy`. Para añadir tus símbolos, edita `EmojiData.js` (ej: `{ ch:"→", name:"flecha", kw:"arrow flecha" }`).

---

## 10. Flujo completo (para fijar ideas)

1. Pulsas atajo → `qs ipc call launcher openSystem` → `forcedMode="system"`, `menuSection="main"`, `launcherVisible=true`.
2. Al abrir: `refreshAll()` (energía/fastfetch/anims + tus `refresh()`), foco en buscador con `">"`.
3. Escribes `> ani` → `activeMode="system"`, `query="ani"` → `systemResults` filtra `systemSearchPool()` → ves "Animaciones Hyprland".
4. `Enter` en un `isSubmenu` → `goSection("animations")` → `refreshSection` → lista dinámica + preview si hay PNG.
5. `Enter` en hoja → `runShell(shellFor(...))` → `launcherVisible=false`.

Abrir `/home` y previsualizar un PDF: modo `files`, `fd` llena `fileSnapshot`, seleccionas el PDF → `FilePreviewService.request` → `ready` → imagen a la derecha.

---

## 11. Chuleta rápida

| Quiero... | Toco... |
|---|---|
| Cambiar prefijos/modos base | `MenuModes.js` (`defs`) |
| Cambiar ventana/lista/preview/atajos | `AppLauncher.qml` |
| Añadir botón fijo clásico | `SystemMenu/*.js` + Registry `staticModules` |
| Añadir sección dinámica interna | `SystemMenuService.qml` + Registry `dynamicInfo` |
| **Crear MI menú (recomendado)** | **Copiar `MenuProviders/MenuProvider.qml` → `MenuProviders/X.qml`** |
| Miniaturas audio/video/pdf/texto | `FilePreviewService.qml` |
| Más emojis | `EmojiData.js` |
| Traducciones | claves `titleKey/subtitleKey` + `I18nService` |

Recarga el shell tras cada cambio en `MenuProviders/` o `SystemMenu/`.

---

*Fin. Si solo te quedas con una frase: **para un menú propio, duplica `MenuProvider.qml`, ponle un `sectionId` único, rellena `entries` con `{titleFallback, iconName, action}` y recarga.***
