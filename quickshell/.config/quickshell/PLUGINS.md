# Plugins de shinro

Sistema de extensiones agnósticas: un plugin solo depende de la API
estable documentada aquí, nunca de rutas internas del shell.
Convive con el core (barra, menús y paneles internos no se tocan):
los plugins **añaden** superficies.

## Ubicación

`~/.config/shinro/plugins/<id>/` (versionado en dotfiles como el resto
de `~/.config/shinro`). Cada plugin es un directorio autocontenido:

```
~/.config/shinro/plugins/mi-plugin/
├── plugin.json      # manifiesto (schema: plugin-schema.json)
├── MiMenu.qml       # componente raíz
└── i18n/            # opcional: es_ES.json, en_US.json, eo.json
```

## Manifiesto

Campos: `id`, `name`, `version`, `author`, `type`
(`launcher` | `bar-widget` | `panel` | `daemon`), `capabilities`,
`component` (ruta relativa, sin `..`), `zone` (bar-widget),
`trigger` (reservado), `settings` (reservado),
`requires_shinro` (`>=1.0`, `1.2.0`, `*`), `permissions`
(declarativo, ver Confianza).

- `id`: `^[a-z0-9][a-z0-9_-]*$`. Reservados: `main`, `todo`,
  `system`, `files`, `web`, `emoji`, `calc`, `clip`,
  `powerprofiles`, `fastfetch`, `animations`, `plugins`.
- **Fase 1: solo `type: "launcher"` se instancia.** El resto se
  lista como disponible y se activará en su fase.

## API estable (contrato agnóstico)

Dentro del componente puedes usar **solo**:

- `qs.Core.Services.*` — singletons (`I18nService`, `MprisService`,
  `ClipboardService`, `PluginService`, …).
- `qs.Core.Modules.*` — `Directories`, `Icons`, `Persistent`, `Screens`.
- `qs.Primitives.*`, `qs.Shared.Background.*` — UI.
- `qs.Core` — **solo lectura** de tokens de tema (`Appearance.md3.*`,
  `Appearance.spacing`, `Appearance.shape`). Equivale al `Theme` de DMS:
  los plugins heredan el tema sin tocar internals.
- `qs.Launcher` — `MenuDefinition` como raíz de menús plugin.
- `PluginService.tr(pluginId, key, fallback)` — i18n con scope.
- `PluginService.getData(pluginId)` / `setData(pluginId, obj)` —
  persistencia namespaced (`~/.local/state/shinro/plugins.json`).

Fuera del contrato (puede romperse entre versiones): `Appearance`
directo, `ConfigService.configs` crudo, rutas relativas al repo.

Si tu raíz declara `property var plugin`, el servicio la inyecta con
`{ id, version, dir }` al instanciar (si no la declara, usa el singleton
`PluginService` directamente con tu id: ambas vías son API estable).
En raíces `MenuDefinition`/`QtObject` la inyección es directa; en el resto
se intenta y se sigue sin contexto si no hay prop (ver fase 2/3).

### Menús launcher

La raíz **debe** ser `MenuDefinition` (mismo contrato que
`MenuProviders/`): `sectionId`, `titleFallback`, `titleKey`,
`iconName`, `parentId`, `entries`, `refresh()` + fábricas
`shell()/ipc()/submenu()/entry()`. Estático o dinámico igual que
un provider normal. Reglas:

- `sectionId` único en todo el shell (core > usuario > plugin:
  si colisiona, el plugin se rechaza con error visible).
- `parentId: "main"` lo lista bajo `>` (Sistema).
- `trigger` (ej. `"!"`): al teclearlo se salta directo a la
  sección del plugin y el resto del texto filtra **dentro** de
  ella (mismos pesos que la búsqueda global). Navegar con
  submenús resetea al `>` normal. Requiere `type: launcher`,
  sin espacios, máx 8 chars, no puede ser `> / @ . = :` ni
  repetirse entre plugins (longest-match gana). Apertura
  profunda también por IPC: `qs ipc call launcher openMenu <section>`.

### Bar widgets

Raíz `Item` con `implicitWidth`/`implicitHeight` (una píldora).
Se instancia **una vez por pantalla** al final de su `zone`
(`left`/`center`/`right`, defecto `right`), ordenados por
(`order`, `id`). `property var plugin` opcional (ver arriba).
Pueden importar `qs.Core` para `Appearance` (tema heredado).

### Daemons

Raíz `Item` no visible (un `QtObject` no admite hijos directos;
`Item` sí vía `data`). Se instancia **una vez** al escanear y vive
hasta el rescan. Verás un aviso cosmético único por escaneo
(`Created graphical object was not placed in the graphics scene`):
inocuo, el objeto nunca se pinta.
Pueden declarar `IpcHandler` propio con target único,
`Timer`/`Process`, y `property var plugin` opcional.
Se reinician en cada `rescan`/`enable`/`disable` (documentado).

### Panels

Raíz `Item` con `implicitWidth`/`implicitHeight` que llene a su
padre (`anchors.fill: parent`); el host le pone ventana
(`PanelWindow`), fondo (`PopupBackground`), foco y Escape.
Apertura: `qs ipc call plugins openPanel <id>` (o una entrada
`ipc` en tu propio menú launcher), cierre: `plugins closePanel`
o Escape / click fuera. `property var plugin` opcional.

### i18n

- Textos fijos: usa `titleFallback` / literales en tu idioma.
- Claves compartidas: `PluginService.tr("<id>", "clave", "Default")`
  mira en `i18n/<idioma>.json` del plugin y cae a
  `plugin.<id>.<clave>` del diccionario global y al default.
- El idioma activo se sigue de `I18nService.language`; al cambiar,
  los plugins se reescanean y los dinámicos se refrescan.

## Ciclo de vida

`Core/Services/PluginService.qml` (singleton):

- Escanea al arrancar, al abrir el launcher (vía
  `SystemMenuRegistry.refreshAll() → checkNow()`, firma `stat`)
  y bajo demanda.
- Los plugins nuevos **activan por defecto** (es tu `~/.config`,
  misma confianza que tu propio QML). Quitar el directorio +
  rescan limpia el estado.
- Todo-o-nada como `MenuStore`: si un rescan falla teniendo
  objetos previos, se conservan los viejos.
- `qs ipc call plugins list|rescan|enable <id>|disable <id>|reload|openPanel <id>|closePanel`.

## Capabilities funcionales (patrón de referencia: fondos)

`capabilities` puede ser funcional, no solo informativo: el core
pregunta `PluginService.providerForCapability(cap)` y obtiene el
**objeto daemon vivo** para llamarlo directamente (sin IPC):

- `wallpaper-backend` (plugin `video-wallpaper`): el core no conoce
  formatos — el proveedor anuncia `extensions` en el manifiesto y el
  servicio enruta `apply()`, filtros del menú y miniaturas por
  coincidencia. Sin proveedor activo no hay rastro. Interfaz:
  `applyWallpaper(path)`, `cachedThumbnail(path) -> ruta|""` +
  `requestThumbnail(path)` (lectura pura + petición explícita),
  `property bool active`, `extensions` en manifiesto. Gana el primero.
- El servicio avisa con `WallpaperService.bumpThumbs()` al generar.
- `applyPosterFrame(path)` del servicio: aplica + notifica (matugen)
  sin persistir (lo necesita cualquier backend animado).
- Reglas: la capability la implementa un **daemon** (objeto único
  y vivo); en otros types es solo informativa. Errores runtime del
  proveedor: `PluginService.noteError/clearError(id)` (visibles
  en `plugins list`).

## Confianza

QML es código arbitrario: **no hay sandbox posible**. Instalar un
plugin es confiar en su autor (mismo modelo que Omarchy: tus
ficheros = confianza total, lo clonado de terceros bajo tu
responsabilidad). `permissions` es documental.

## Crear uno

`~/.config/shinro/new-plugin.sh <id> "<Nombre>" [launcher]` genera
el esqueleto válido. Ver `plugins/_example-hello/` como referencia
viva (sección de ejemplo bajo `>`).

## Roadmap

- Fase 2: `bar-widget` (slot por zona en `MainBar`) + `trigger`. ✔
- Fase 3: `daemon` (Scope único) + `panel` (host genérico). ✔
- Fase 4: pestaña Plugins en Ajustes (toggle, errores, settings UI).
