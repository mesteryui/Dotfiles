# Hyprland Lua Configuration Standards

Este documento define las normas y convenciones para mantener y extender la configuración de Hyprland basada en Lua.

## 🏗 Arquitectura y Estructura

La configuración es modular y utiliza `hyprland-lua` como puente.

- **Punto de Entrada:** `hyprland.lua`. Aquí se definen variables globales y se cargan los módulos.
- **Módulos:** Ubicados en `configs/`. Cada aspecto de la configuración (teclas, reglas, monitores) tiene su propio archivo.
- **Sub-módulos:** Para áreas complejas como reglas de ventanas, se usan subcarpetas (ej. `configs/rules_windows/`).

## 🛠 Herramientas y Desarrollo

### IntelliSense y Tipado (Stubs)
Para que el servidor de lenguaje Lua (LSP) proporcione autocompletado y diagnósticos correctos:
- Se utilizan los stubs ubicados en `/usr/share/hypr/stubs`.
- El archivo `.luarc.json` ya está configurado para incluir esta biblioteca y reconocer `hl` como un global.
- **Regla:** Siempre trabajar en un entorno que respete el `.luarc.json` para evitar errores de sintaxis y aprovechar el tipado.

### El Global `hl`
Casi todas las interacciones con Hyprland se realizan a través del objeto global `hl`.
- `hl.bind(...)`: Para atajos de teclado.
- `hl.dsp`: Para acceder a los dispatchers (ej. `hl.dsp.focus`).
- `hl.config({ ... })`: Para establecer opciones de Hyprland (decoración, general, etc.).
- `hl.env(key, value)`: Para variables de entorno.
- `hl.window_rule({ ... })`: Para reglas de ventanas.
- `hl.on("evento", callback)`: Para reaccionar a eventos de Hyprland.

## 📝 Convenciones de Código

### Ejecución de Aplicaciones
- **Regla:** Utilizar siempre `uwsm app --` para lanzar aplicaciones (ej. `uwsm app -- kitty`). Esto asegura una gestión correcta de la sesión y los recursos.
- Ejemplo en atajos: `hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("uwsm app -- " .. terminal))`

### Atajos de Teclado (Bindings)
- Siempre incluir una `description` en los bindings para facilitar su documentación o visualización en OSD.
- Ejemplo: `hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("uwsm app -- " .. fileManager), { description = "Abrir gestor de archivos" })`

### Atajos dependientes del layout
- La tecla y la intención no cambian entre layouts; solo cambia la implementación, definida en `configs/layout_actions.lua`.
- Usar `layout_actions.bind(layout_actions.actions.<accion>, { name = "..." })` para acciones dependientes del layout (`swap_*`, `rotate_split`, `fit_center`, `resize_*`, `width_*`), en lugar de elegir un dispatcher distinto según el layout dentro del callback.
- Acciones adaptadas por layout: `swap_*`, `rotate_split`, `fit_center`, `resize_*` y `width_*`.
- **Foco y movimiento usan siempre el dispatcher genérico** (`hl.dsp.focus` y `hl.dsp.window.move`) en todos los layouts, incluido `monocle`. No se enrutan por `layout_actions`: `SUPER+DIRECCIÓN` enfoca y `SUPER+SHIFT+DIRECCIÓN` mueve.
- Los atajos `SUPER+ALT+...` son acciones estructurales de layout/columna y sí pasan por `layout_actions`.
- Definir las claves `scrolling`, `dwindle`, `master`, `monocle` y, si existe un equivalente universal real, `default` (genérico, también para layouts `lua:*`).
- Si el layout no define la acción, se usa `default` (el dispatcher genérico). Usar `false` solo cuando no exista un equivalente genérico real: el helper avisa una vez y no ejecuta nada. No se debe sustituir por una acción no relacionada.
- Si una acción declara `floating`, el helper la usa cuando la ventana activa es flotante, porque los mensajes de layout la ignoran (no pertenece a ninguna columna). `floating = false` significa "no se aplica a flotantes": avisa una vez y no ejecuta la acción del layout.
- La `description` describe la intención, nunca el nombre del layout ni el mensaje interno.
- Probar la acción en los cuatro layouts antes de darla por terminada.
- En `scrolling`, `swap_*` usa `swapcol`; `scrolling:wrap_swapcol` y `scrolling:wrap_focus` se dejan en `false` para que el borde no dé la vuelta y coincida con dwindle/master.
- En `scrolling`, las acciones de ancho no se ejecutan cuando hay una sola columna y `fullscreen_on_one_column = true`: el cambio sería invisible. El helper avisa en vez de mutar un ancho que no se ve.

### Resize dependiente del layout
- La intención es la misma ("más ancho", "más alto"), pero la unidad no:
  - `scrolling`: el ancho es propiedad de la **columna**, así que se usa `layoutmsg colresize ±0.02` (fracción del área útil, acotada a `[0.05, 1.0]`). Hyprland reencuadra la columna después del cambio.
  - `dwindle`, `master` y layouts `lua:*`: `hl.dsp.window.resize({ x, y, relative = true })`; ahí el delta mueve el borde de la división.
  - `monocle`: `false`, no hay geometría que repartir.
  - Ventanas flotantes: en `resize_*` siempre usan píxeles mediante `floating`. Las acciones estructurales (`swap_*`, `rotate_split`) declaran `floating = false`.
- En `scrolling` la altura no pertenece a la ventana: se reparte entre las ventanas de la misma columna. Con una sola ventana no hay nada que ajustar, así que `resize_taller`/`resize_shorter` avisan una vez en lugar de fallar en silencio.
- Presets: `width_cycle` (`colresize +conf`, recorre `scrolling:explicit_column_widths`) y `width_reset` (vuelve a `scrolling:column_width`). Solo existen en `scrolling`. Con una sola columna se guardan con aviso, porque el ancho no se ve.
- El submapa `resize` se genera desde `layout_actions`; no escribas dispatchers de resize a mano en `configs/submaps.lua`.

### Variables Globales de Usuario
- Definir constantes globales de usuario en `hyprland.lua` usando `_G` para que estén disponibles en todos los módulos (ej. `_G.mainMod`, `_G.terminal`).

### Robustez y Refactorización
- **Modularización Extrema:** Si un archivo de configuración crece demasiado, divídelo en sub-archivos dentro de una subcarpeta dedicada en `configs/`.
- **Validación:** Antes de realizar cambios profundos, verifica que el `hl.get_config` se use correctamente para leer estados actuales si es necesario (como en `helper.gamemode.toggle` en `some_funcs.lua`).
- **Notificaciones Estándar:** Utilizar `helper.notify(text, level)` para proporcionar feedback visual consistente al usuario sin duplicar lógica de colores.

## 📂 Organización de Archivos
- `configs/keybinds.lua`: Atajos de teclado generales.
- `configs/windowrules.lua`: Reglas de ventanas (clases, títulos, flotado).
- `configs/appearance.lua`: Configuración estética (bordes, sombras, blur).
- `configs/animation.lua`: Configuración de animaciones (curvas, velocidades).
- `scripts/`: Scripts auxiliares en Bash/Fish/Python.

---
*Este archivo es una guía viva. Si se introducen nuevos patrones, deben documentarse aquí.*
