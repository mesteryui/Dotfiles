-- configs/rules_windows/terminals.lua
-- Reglas de comportamiento para emuladores de terminal

local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"

-- Forzar opacidad 1.0 override para respetar la configuración interna de la terminal
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" })

-- Asignar tag +terminal a emuladores conocidos
hl.window_rule({ match = { class = "(Alacritty|kitty|com.mitchellh.ghostty)" }, tag = "+terminal" })

-- Terminal flotante local
hl.window_rule({ match = { class = "^(local\\.floating)$" }, tag = "+floating-term" })

-- Configuración de terminales marcadas como flotantes
hl.window_rule({
    name = "tag-floating-term",
    match = { tag = "floating-term" },
    float = true,
    center = true,
    size = { 800, 700 },
})
