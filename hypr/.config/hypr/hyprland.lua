-- hyprland.lua
-- █░█ █▄█ █▀█ █▀█ █░░ ▄▀█ █▄░█ █▀▄
-- █▀█ ░█░ █▀▀ █▀▄ █▄▄ █▀█ █░▀█ █▄▀

-- Global variables (can be used in required files if needed, but better to pass or define as locals)
_G.terminal = "uwsm app -- xdg-terminal-exec"
_G.fileManager = "dolphin"
--_G.fileManager = terminal.." -e yazi"
_G.browser = "firefox"
_G.emacs = "emacsclient -c -a 'emacs'"
_G.Colors = require("colors")
_G.DefaultMonitor = "eDP-1"

_G.helper = require("configs.some_funcs")

-- Carga de configuraciones de menús/lanzadores
require("configs.walker_menu")

-- --- ENTORNO Y SEGURIDAD ---
require("configs.env")
require("configs.permissions")
require("configs.plugins")


hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload")
end)

-- --- HARDWARE & MONITORES ---
require("configs.monitors")
require("configs.workspaces")
require("configs.devices")
require("configs.gestures")

-- --- ESTÉTICA & COLORES ---
require("configs.appearance")
require("configs.animation")

-- --- REGLAS DE VENTANAS Y CAPAS ---
require("configs.windowrules")
require("configs.layerrules")

-- --- FUNCIONALIDAD & ATAJOS ---
require("configs.submaps")
require("configs.keybinds")
require("configs.auto-exec")

-- --- OTROS ---
require("configs.miscelanea")
