-- configs/walker_menu.lua
-- ÚNICO FICHERO de comandos de menús. Todos los keybinds usan estas
-- variables; aquí se elige el backend sin tocar ningún atajo:
--   quickshell launcher  → "qs ipc call launcher ..."
--   elephant + walker    → comandos "walker ..." (dejados como fallback)
-- Para volver a walker: comenta el bloque quickshell y descomenta el de
-- walker, luego `hyprctl reload`. Nada más que tocar.

-- === quickshell launcher (activo) ===
_G.menu = "qs ipc call launcher toggle" -- Todo/Aplicaciones
_G.system_menu = "qs ipc call launcher openSystem" -- Sistema (secciones >)
_G.clipboard_menu = "qs ipc call launcher openClipboard" -- Portapapeles
_G.emoji_menu = "qs ipc call launcher openEmoji" -- Emojis/símbolos
_G.files_menu = "qs ipc call launcher toggleMode files" -- Archivos (/)
_G.web_menu = "qs ipc call launcher toggleMode web" -- Web (@, sin atajo)
_G.calc_menu = "qs ipc call launcher toggleMode calc" -- Calculadora (=, sin atajo)
_G.screenshot_menu = "qs ipc call launcher openMenu screenshot" -- Capturas
-- Menú principal (equivale a `menu` en la era walker, donde ambos eran
-- "walker" a pelo). No es cambio de layout de teclado: abre el launcher.
_G.menu_layout_changer = "qs ipc call launcher toggle"
_G.wallpaper_selector = "qs ipc call ui.wallpaperMenu toggleWallpaperMenu"
-- _G.bar_layout_selector: sin equivalente en quickshell, sigue en walker.
_G.bar_layout_selector = "walker -m menus:waybar-layout-selector"

-- === elephant + walker (fallback: descomentar para volver) ===
-- _G.menu = "walker"
-- _G.system_menu = "walker -s hyprsphere"
-- _G.clipboard_menu = "walker -m clipboard"
-- _G.emoji_menu = "walker -m symbols"
-- _G.files_menu = "walker -m files"
-- _G.web_menu = "walker -m websearch"
-- _G.calc_menu = "walker -m calc"
-- _G.screenshot_menu = "walker -m menus:screenshot"
-- _G.menu_layout_changer = "walker"
-- _G.wallpaper_selector = "walker -m menus:wallpapers"
