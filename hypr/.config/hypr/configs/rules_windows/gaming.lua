-- configs/rules_windows/gaming.lua
-- Reglas y optimizaciones de rendimiento para Steam y videojuegos

-- Regla para Cartridges (lanzador de juegos)
hl.window_rule({ match = { class = "^(.*Cartridges)$" }, float = true })

-- 1. Reglas específicas para Steam
hl.window_rule({
    name = "steam-base",
    match = { class = "^(steam)$" },
    float = true,
    opacity = "1.0 override 1.0 override 1.0 override",
    idle_inhibit = "focus",
})

hl.window_rule({
    name = "steam-main",
    match = { class = "^(steam)$", title = "^(Steam)$" },
    size = { 1100, 700 },
    center = true,
})

hl.window_rule({
    name = "steam-friends",
    match = { class = "^(steam)$", title = "^(Friends List)$" },
    size = { 460, 800 },
})

hl.window_rule({
    name = "steam-fullscreen",
    match = { class = "^(steam)$", fullscreen = true },
    idle_inhibit = "fullscreen",
})

-- 2. Detección y optimización de juegos lanzados por Steam/Gamescope
local gamingApps = "^(steam_app.*|gamescope)$"

hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*)$",
    },
    content          = "game",
    decorate         = false,
    fullscreen_state = 2,
    size             = { "monitor_w", "monitor_h" },
    sync_fullscreen  = true,
})

-- 3. Reglas y optimizaciones para todos los juegos (tag "game")
hl.window_rule({
    name = "proton-game-tag",
    match = {
        xdg_tag = "proton-game",
    },
    tag = "+game",
})

hl.window_rule({
    name = "games",
    match = {
        tag = "game",
        fullscreen = true,
    },
    border_size = 0,
    rounding = 0,
    decorate = false,
    force_rgbx = true,
    sync_fullscreen = true,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_max_size = true,
    no_shadow = true,
    persistent_size = true,
    focus_on_activate = true,
    immediate = true,
})
