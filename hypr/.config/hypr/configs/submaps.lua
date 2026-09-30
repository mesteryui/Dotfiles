hl.define_submap("resize", function()
  -- Redimensionado para layouts estándar ('dwindle', 'master', etc.)
  hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true, description = "Redimensionar: Aumentar ancho" })
  hl.bind("left", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true, description = "Redimensionar: Reducir ancho" })
  hl.bind("up", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Redimensionar: Reducir alto" })
  hl.bind("down", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Redimensionar: Aumentar alto" })

  -- Modo Vim (HJKL)
  hl.bind("L", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true, description = "Redimensionar: Aumentar ancho" })
  hl.bind("H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true, description = "Redimensionar: Reducir ancho" })
  hl.bind("K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Redimensionar: Reducir alto" })
  hl.bind("J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Redimensionar: Aumentar alto" })

  -- Usa `reset` para volver al submapa global
  helper.submap.exitSubmap("escape", { description = "Submapas: Salir del modo redimensionar" })
end)

hl.define_submap("Multimedia", function()
  local playerctl_manager = "qs ipc call mpris"
  local keys = {
    S = { "playPause", "Multimedia: Reproducir/Pausar" },
    P = { "previous", "Multimedia: Pista anterior" },
    N = { "next", "Multimedia: Siguiente pista" }
  }
  for key, action in pairs(keys) do
    hl.bind(key, hl.dsp.exec_cmd(playerctl_manager .. " " .. action[1]), { description = action[2] })
  end
  helper.submap.exitSubmap("escape", { description = "Submapas: Salir del modo multimedia" })
end)

hl.define_submap("Passthrough", function()
  helper.submap.exitSubmap("escape", { description = "Submapas: Salir del modo passthrough (recuperar control)" })
end)

-- Keybinds further down will be global again...
