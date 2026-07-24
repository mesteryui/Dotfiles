-- configs/rules_windows/system_fixes.lua
-- Correcciones de compatibilidad, XWayland y eventos del sistema

-- Evitar blur en ventanas anónimas (menús, tooltips de algunas apps)
hl.window_rule({
    name = "noblur-anonymous",
    match = { class = "^$", title = "^$" },
    no_blur = true,
})

-- Corrección para arrastrar y soltar en aplicaciones XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Ignorar eventos de maximizado solicitados por las aplicaciones
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
