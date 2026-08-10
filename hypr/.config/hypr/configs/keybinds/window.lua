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

--hl.bind(mainMod.." + O", function ()
--    if helper.check_plugin("hyprexpo", "Hyprexpo") then
--        hl.plugin.hyprexpo.expo("toggle")
--    end
--end, {description = "Abrir/Cerrar Hyprexpo"})

hl.bind(mainMod .. " + O", function()
  if helper.check_plugin("scrolloverview", "Scrolloverview") then
    hl.plugin.scrolloverview.overview("toggle all")
  end
end, { description = "Abrir/Cerrar Scrolloverview" })
-- Definición de direcciones y teclas (HJKL y Flechas)
local movement_dirs = {
    { dir = "left",  short_code = "l", nombre = "izquierda", teclas = { "H", "LEFT" } },
    { dir = "right", short_code = "r", nombre = "derecha",   teclas = { "L", "RIGHT" } },
    { dir = "up",    short_code = "u", nombre = "arriba",    teclas = { "K", "UP" } },
    { dir = "down",  short_code = "d", nombre = "abajo",     teclas = { "J", "DOWN" } }
}

local current_layout = hl.get_config("general.layout")

if current_layout == "scrolling" then
    -- Atajos de navegación y movimiento adaptados para layout 'scrolling'
    for _, item in ipairs(movement_dirs) do
        for _, key in ipairs(item.teclas) do
            -- Foco usando dispatcher nativo de scrolling (focus l/r/u/d)
            hl.bind(mainMod .. " + " .. key, hl.dsp.layout("focus " .. item.short_code),
                { description = "Cambiar foco a la " .. item.nombre .. " (scrolling)" })

            -- Mover/Intercambiar ventana en scrolling (swapcol para l/r, move para u/d)
            if item.dir == "left" or item.dir == "right" then
                hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.layout("swapcol " .. item.short_code),
                    { description = "Intercambiar columna a la " .. item.nombre })
            else
                hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = item.dir }),
                    { description = "Mover ventana hacia " .. item.nombre })
            end
        end
    end

    -- Atajos auxiliares específicos para scrolling
    hl.bind(mainMod .. " + comma", hl.dsp.layout("move -col"), { description = "Desplazarse a la columna anterior (-col)" })
    hl.bind(mainMod .. " + period", hl.dsp.layout("move +col"), { description = "Desplazarse a la columna siguiente (+col)" })
    hl.bind(mainMod .. " + ALT + P", hl.dsp.layout("promote"), { description = "Promocionar ventana a nueva columna" })
    hl.bind(mainMod .. " + ALT + F", hl.dsp.layout("fit active"), { description = "Ajustar ventana activa al ancho de columna" })
else
    -- Atajos de navegación y movimiento para dwindle / layouts estándar
    for _, item in ipairs(movement_dirs) do
        for _, key in ipairs(item.teclas) do
            hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = item.dir }),
                { description = "Cambiar foco a la " .. item.nombre })

            hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = item.dir }),
                { description = "Mover ventana hacia la " .. item.nombre })
        end
    end

    if current_layout == "dwindle" then
        hl.bind(mainMod .. " + ALT + J", hl.dsp.layout("togglesplit"), { description = "Alternar división de ventana (dwindle)" })
        hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Alternar pseudotiling (dwindle)" })
    end
end

hl.bind("ALT + R", hl.dsp.submap("resize"), { description = "Entrar al submapa de redimensionamiento" })
