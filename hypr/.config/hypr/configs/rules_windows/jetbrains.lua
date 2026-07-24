-- configs/rules_windows/jetbrains.lua
-- Reglas y correcciones específicas para IDEs de JetBrains

hl.window_rule({
    match = { class = "^(jetbrains-.*)$", title = "^(splash)$", float = true },
    center = true,
    no_focus = true,
    border_size = 0,
})

hl.window_rule({
    match = { class = "^jetbrains-.*$", float = true, title = "^$|^\\s$|^win\\d+$" },
    no_initial_focus = true,
})

hl.window_rule({
    match = { class = "^(jetbrains-.*)$" },
    no_follow_mouse = true,
})
