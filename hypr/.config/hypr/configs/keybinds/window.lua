hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Ventanas: Cerrar ventana" })

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Ventanas: Alternar flotado" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { description = "Ventanas: Alternar pantalla completa" })
hl.bind("ALT + TAB", hl.dsp.global("quickshell:windowSwitcher"), { description = "Ventanas: Cambiar entre aplicaciones" })

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
end, { description = "Ventanas: Alternar hyprbars" })

--hl.bind(mainMod.." + O", function ()
--    if helper.check_plugin("hyprexpo", "Hyprexpo") then
--        hl.plugin.hyprexpo.expo("toggle")
--    end
--end, {description = "Abrir/Cerrar Hyprexpo"})

hl.bind(mainMod .. " + O", function()
  if helper.check_plugin("scrolloverview", "Scrolloverview") then
    hl.plugin.scrolloverview.overview("toggle all")
  end
end, { description = "Ventanas: Abrir/Cerrar Scrolloverview" })
-- Definición de direcciones y teclas (HJKL y Flechas)
local movement_dirs = {
    { dir = "left",  short_code = "l", nombre = "izquierda", teclas = { "H", "LEFT" } },
    { dir = "right", short_code = "r", nombre = "derecha",   teclas = { "L", "RIGHT" } },
    { dir = "up",    short_code = "u", nombre = "arriba",    teclas = { "K", "UP" } },
    { dir = "down",  short_code = "d", nombre = "abajo",     teclas = { "J", "DOWN" } }
}

-- Atajos de navegación y movimiento para dwindle / layouts estándar
for _, item in ipairs(movement_dirs) do
    for _, key in ipairs(item.teclas) do
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = item.dir }),
            { description = "Ventanas: Cambiar foco a la " .. item.nombre })

        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = item.dir }),
            { description = "Ventanas: Mover ventana hacia la " .. item.nombre })
    end
end

hl.bind("ALT + R", hl.dsp.submap("resize"), { description = "Submapas: Entrar al modo redimensionar" })