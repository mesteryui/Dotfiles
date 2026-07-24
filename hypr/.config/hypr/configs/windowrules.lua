-- configs/windowrules.lua
-- Archivo principal de reglas de ventanas. Orquesta la carga de submódulos.

local modules = {
    "configs.rules_windows.system_fixes",     -- Fixes de XWayland, eventos y compatibilidad
    "configs.rules_windows.workspaces",       -- Asignación de aplicaciones a workspaces específicos
    "configs.rules_windows.floating",         -- Reglas para diálogos, modales y aplicaciones flotantes
    "configs.rules_windows.terminals",        -- Reglas específicas para terminales (opacidad, tags, etc.)
    "configs.rules_windows.gaming",           -- Reglas para juegos, Steam, proton y optimizaciones
    "configs.rules_windows.jetbrains",        -- Fixes y reglas de comportamiento para IDEs de JetBrains
    "configs.rules_windows.btop",             -- Regla específica para btop flotante
    "configs.rules_windows.PictureInPicture",     -- Regla específica para Picture-in-Picture
    "configs.rules_windows.apps",             -- Reglas específicas para otras aplicaciones (Telegram, navegadores, etc.)
}

for _, module in ipairs(modules) do
    require(module)
end
