hl.define_submap("resize", function()
  -- La intención es la misma en todos los layouts; el dispatcher lo resuelve
  -- configs/layout_actions.lua según el layout de la ventana activa.
  local ok, layout_actions = pcall(require, "configs.layout_actions")
  if not ok then
    print("shinro: no se pudo cargar configs.layout_actions: " .. tostring(layout_actions))
    return
  end

  local A = layout_actions.actions

  -- Cada intención se expone en flechas y en HJKL para no duplicar binds.
  local intents = {
    { arrows = "right", vim = "L", action = A.resize_wider, nombre = "Aumentar ancho" },
    { arrows = "left", vim = "H", action = A.resize_narrower, nombre = "Reducir ancho" },
    { arrows = "down", vim = "J", action = A.resize_taller, nombre = "Aumentar alto" },
    { arrows = "up", vim = "K", action = A.resize_shorter, nombre = "Reducir alto" },
  }

  for _, item in ipairs(intents) do
    for _, key in ipairs({ item.arrows, item.vim }) do
      hl.bind(
        key,
        layout_actions.bind(item.action, { name = item.nombre }),
        { repeating = true, description = "Redimensionar: " .. item.nombre }
      )
    end
  end

  -- Presets de ancho: la unidad es la columna, así que solo existen en scrolling.
  hl.bind("W", layout_actions.bind(A.width_cycle, { name = "Siguiente ancho" }), { description = "Redimensionar: Siguiente ancho de columna" })
  hl.bind("R", layout_actions.bind(A.width_reset, { name = "Restablecer ancho" }), { description = "Redimensionar: Restablecer ancho de columna" })

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
