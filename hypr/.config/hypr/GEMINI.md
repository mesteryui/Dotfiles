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
