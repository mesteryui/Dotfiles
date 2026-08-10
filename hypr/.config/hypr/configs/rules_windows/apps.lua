-- configs/rules_windows/apps.lua
-- Reglas específicas para aplicaciones de productividad y navegadores

-- Telegram: evitar enfocar automáticamente al activarse para no interrumpir el flujo de trabajo
hl.window_rule({
    match = { class = "org.telegram.desktop" },
    focus_on_activate = false,
})

-- Navegadores: forzar opacidad completa para no interferir con la legibilidad
--hl.window_rule({
--    match = { class = "^(firefox|zen)$" },
--    opacity = "1.0 override",
--})

hl.window_rule({match = {class = "^(plasma-changeicons)$" }, float = true})
hl.window_rule({match = {class = "^(plasma-changeicons)$" }, no_initial_focus = true})
hl.window_rule({match = {class = "^(plasma-changeicons)$" }, move = {999999, 999999}})
-- stupid dolphin copy
hl.window_rule({match = {title = "^(Copying — Dolphin)$" }, move = {40, 80}})
