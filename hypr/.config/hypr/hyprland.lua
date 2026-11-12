-- hyprland.lua
-- █░█ █▄█ █▀█ █▀█ █░░ ▄▀█ █▄░█ █▀▄
-- █▀█ ░█░ █▀▀ █▀▄ █▄▄ █▀█ █░▀█ █▄▀

-- Global variables (can be used in required files if needed, but better to pass or define as locals)
_G.terminal = "uwsm app -- xdg-terminal-exec"
_G.fileManager = "nautilus"
--_G.fileManager = terminal.." -e yazi"
_G.browser = "zen-browser"
_G.emacs = "emacsclient -c -a 'emacs'"
_G.Colors = require("colors")
_G.DefaultMonitor = "eDP-1"
_G.helper = require("configs.some_funcs")

-- optional(mod): carga un drop-in solo si existe y degrada con pcall si está
-- roto, en vez de tumbar toda la config al overlay "has errors" / emergency
-- mode. Patrón de Ryoku (ryoku/hyprland/hyprland.lua): Hyprland reporta hasta
-- el require() con pcall de un módulo inexistente, así que se sondea la ruta
-- antes. Reservar require() duro para lo crítico (colors, some_funcs, env);
-- todo lo demás va por aquí.
local function optional(mod)
	if package.searchpath == nil or package.searchpath(mod, package.path) then
		local ok, err = pcall(require, mod)
		if not ok then
			print("shinro: optional config module '" .. mod .. "' failed to load: " .. tostring(err))
		end
	end
end

-- Carga de configuraciones de menús/lanzadores
optional("configs.walker_menu")

-- --- ENTORNO Y SEGURIDAD ---
require("configs.env")
require("configs.permissions")
require("configs.plugins")

hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpm reload")
end)

-- --- HARDWARE & MONITORES ---
optional("configs.monitors")
optional("configs.workspaces")
optional("configs.devices")
optional("configs.gestures")

-- --- ESTÉTICA & COLORES ---
optional("configs.appearance")
optional("configs.animation")

-- --- REGLAS DE VENTANAS Y CAPAS ---
optional("configs.windowrules")
optional("configs.layerrules")

-- --- FUNCIONALIDAD & ATAJOS ---
optional("configs.submaps")
optional("configs.keybinds")
optional("configs.auto-exec")

-- --- OTROS ---
optional("configs.miscelanea")
