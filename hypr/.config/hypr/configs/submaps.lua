hl.define_submap("resize", function()
  -- Set repeating binds for resizing the active window.
  hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0, relative = true }),
  { repeating = true, description = "Aumentar ancho" })
hl.bind("left", hl.dsp.window.resize({ x = -10, y = 0, relative = true }),
  { repeating = true, description = "Reducir ancho" })

-- Dimensionar Alto (Eje Y)
hl.bind("up", hl.dsp.window.resize({ x = 0, y = -10, relative = true }),
  { repeating = true, description = "Reducir alto" })
hl.bind("down", hl.dsp.window.resize({ x = 0, y = 10, relative = true }),
  { repeating = true, description = "Aumentar alto" })

-- Atajos modo Vim (HJKL)
hl.bind("L", hl.dsp.window.resize({ x = 10, y = 0, relative = true }),
  { repeating = true, description = "Aumentar ancho" })
hl.bind("H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }),
  { repeating = true, description = "Reducir ancho" })
hl.bind("K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }),
  { repeating = true, description = "Reducir alto" })
hl.bind("J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }),
  { repeating = true, description = "Aumentar alto" })

  -- Use `reset` to go back to the global submap
  helper.submap.exitSubmap("escape",{ description = "Salir del modo redimensionar" })
end)

hl.define_submap("Multimedia", function()
  local playerctl_manager = "swayosd-client --playerctl"
  local keys = {
    S = { "play-pause", "Reproducir/Pausar" },
    P = { "prev", "Pista anterior" },
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
