-- hyprland.lua
-- █░█ █▄█ █▀█ █▀█ █░░ ▄▀█ █▄░█ █▀▄
-- █▀█ ░█░ █▀▀ █▀▄ █▄▄ █▀█ █░▀█ █▄▀

-- Global variables (can be used in required files if needed, but better to pass or define as locals)
_G.mainMod = "SUPER"
_G.terminal = "uwsm app -- xdg-terminal-exec"
_G.fileManager = "dolphin"
_G.browser = "firefox"
_G.emacs = "emacsclient -c -a 'emacs'"
_G.Colors = require("colors")
_G.DefaultMonitor = "eDP-1"

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
require("configs.keybinds")
require("configs.submaps")
require("configs.auto-exec")

-- --- OTROS ---
require("configs.miscelanea")
require("configs.battery")
