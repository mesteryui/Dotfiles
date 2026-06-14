hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close(), { description = "Cerrar ventana" })

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Alternar flotado" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { description = "Alternar pantalla completa" })
hl.bind("ALT + TAB", hl.dsp.exec_cmd("sleep 0.5;snappy-switcher toggle"), { description = "Cambiar entre aplicaciones" })

hl.bind(mainMod .. " + F12", function()
    if not helper.check_plugin("hyprbars", "Hyprbars") then
      return
    end
    local pl_key = "plugin.hyprbars.enabled"
    local is_enabled = hl.get_config(pl_key)
    if is_enabled then
        hl.config({ [pl_key] = false })
    else
        hl.config({ [pl_key] = true })
    end
end, { description = "Alternar hyprbars" })

hl.bind(mainMod.." + O", function ()
    if helper.check_plugin("hyprexpo", "Hyprexpo") then
        hl.plugin.hyprexpo.expo("toggle")
    end
end, {description = "Abrir/Cerrar Hyprexpo"})

-- Focus & Move
local movement = {
    { dir = "left",  nombre = "izquierda", teclas = { "H", "LEFT" } },
    { dir = "right", nombre = "derecha",   teclas = { "L", "RIGHT" } },
    { dir = "up",    nombre = "arriba",    teclas = { "K", "UP" } },
    { dir = "down",  nombre = "abajo",     teclas = { "J", "DOWN" } }
}

for _, item in ipairs(movement) do
    for _, key in ipairs(item.teclas) do
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = item.dir }),
            { description = "Cambiar foco a la " .. item.nombre })

        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = item.dir }),
            { description = "Mover ventana hacia la " .. item.nombre })
    end
end

hl.bind("ALT + R", hl.dsp.submap("resize"), { description = "Entrar al submapa de redimensionamiento" })
