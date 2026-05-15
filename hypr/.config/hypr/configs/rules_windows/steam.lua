-- configs/rules_windows/steam.lua
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
    size = "1100 700",
    center = true,
})

hl.window_rule({
    name = "steam-friends",
    match = { class = "^(steam)$", title = "^(Friends List)$" },
    size = "460 800",
})

hl.window_rule({
    name = "steam-fullscreen",
    match = { class = "^(steam)$", fullscreen = true },
    idle_inhibit = "fullscreen",
})
