-- configs/rules_windows/workspaces.lua
-- Asignación de aplicaciones a espacios de trabajo (workspaces) específicos

hl.window_rule({ match = { class = "vesktop" }, workspace = 5 })
hl.window_rule({ match = { class = "gimp" },    workspace = 4 })
