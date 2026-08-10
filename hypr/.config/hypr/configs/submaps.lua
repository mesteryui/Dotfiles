hl.define_submap("resize", function()
  local layout = hl.get_config("general.layout")

  if layout == "scrolling" then
    -- Redimensionado para layout 'scrolling' (ajusta ancho de columna y alto de ventana)
    hl.bind("right", hl.dsp.layout("colresize +0.02"), { repeating = true, description = "Aumentar ancho de columna" })
    hl.bind("left", hl.dsp.layout("colresize -0.02"), { repeating = true, description = "Reducir ancho de columna" })
    hl.bind("up", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Reducir alto" })
    hl.bind("down", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Aumentar alto" })

    -- Modo Vim (HJKL)
    hl.bind("L", hl.dsp.layout("colresize +0.02"), { repeating = true, description = "Aumentar ancho de columna" })
    hl.bind("H", hl.dsp.layout("colresize -0.02"), { repeating = true, description = "Reducir ancho de columna" })
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Reducir alto" })
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Aumentar alto" })
  else
    -- Redimensionado para layouts estándar ('dwindle', 'master', etc.)
    hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true, description = "Aumentar ancho" })
    hl.bind("left", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true, description = "Reducir ancho" })
    hl.bind("up", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Reducir alto" })
    hl.bind("down", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Aumentar alto" })

    -- Modo Vim (HJKL)
    hl.bind("L", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true, description = "Aumentar ancho" })
    hl.bind("H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true, description = "Reducir ancho" })
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Reducir alto" })
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Aumentar alto" })
  end

  -- Usa `reset` para volver al submapa global
  helper.submap.exitSubmap("escape", { description = "Salir del modo redimensionar" })
end)

hl.define_submap("Multimedia", function()
  local playerctl_manager = "qs ipc call mpris"
  local keys = {
    S = { "playPause", "Reproducir/Pausar" },
    P = { "previous", "Pista anterior" },
    N = { "next", "Siguiente pista" }
  }
  for key, action in pairs(keys) do
    hl.bind(key, hl.dsp.exec_cmd(playerctl_manager .. " " .. action[1]), { description = action[2] })
  end
  helper.submap.exitSubmap("escape", { description = "Salir del modo multimedia" })
end)

hl.define_submap("Passthrough", function()
  helper.submap.exitSubmap("escape", { description = "Salir del modo passthrough (recuperar control)" })
end)

-- Keybinds further down will be global again...
