-- configs/keybinds/init.lua

_G.mainMod = "SUPER"

-- Respaldo: si walker_menu.lua no se ejecutó antes (recargas parciales
-- del watcher de hypr tras un checkout: files_menu/screenshot_menu
-- llegaban nil y tumbaban TODA la config), se fijan aquí los mismos
-- comandos. No pisa lo que walker_menu ya definiera (or).
_G.menu = _G.menu or "qs ipc call launcher toggle"
_G.system_menu = _G.system_menu or "qs ipc call launcher openSystem"
_G.clipboard_menu = _G.clipboard_menu or "qs ipc call launcher openClipboard"
_G.emoji_menu = _G.emoji_menu or "qs ipc call launcher openEmoji"
_G.files_menu = _G.files_menu or "qs ipc call launcher toggleMode files"
_G.web_menu = _G.web_menu or "qs ipc call launcher toggleMode web"
_G.calc_menu = _G.calc_menu or "qs ipc call launcher toggleMode calc"
_G.screenshot_menu = _G.screenshot_menu or "qs ipc call launcher openMenu screenshot"
_G.menu_layout_changer = _G.menu_layout_changer or "qs ipc call launcher toggle"
_G.wallpaper_selector = _G.wallpaper_selector or "qs ipc call ui.wallpaperMenu toggleWallpaperMenu"
_G.bar_layout_selector = _G.bar_layout_selector or "walker -m menus:waybar-layout-selector"

-- Carga explícita de módulos de atajos
require("configs.keybinds.workspaces")
require("configs.keybinds.apps")
require("configs.keybinds.media")
require("configs.keybinds.system")
require("configs.keybinds.window")
