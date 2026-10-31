-- configs/keybinds/layout.lua
--
-- Atajos estructurales de layout/columna que se adaptan al layout activo sin
-- cambiar de tecla ni de intención. La lógica vive en configs/layout_actions.lua.
-- El foco y el movimiento genéricos viven en configs/keybinds/window.lua.

local ok, layout_actions = pcall(require, "configs.layout_actions")
if not ok then
    print("shinro: no se pudo cargar configs.layout_actions: " .. tostring(layout_actions))
    return
end

local actions = layout_actions.actions

hl.bind(mainMod .. " + ALT + H", layout_actions.bind(actions.swap_left, { name = "Intercambiar a la izquierda" }), {
    description = "Ventanas: Intercambiar con el vecino de la izquierda",
})

hl.bind(mainMod .. " + ALT + L", layout_actions.bind(actions.swap_right, { name = "Intercambiar a la derecha" }), {
    description = "Ventanas: Intercambiar con el vecino de la derecha",
})

-- Se mantiene la descripción original para no moverlo de categoría en la
-- cheat sheet: en dwindle alterna la división; en master rota la orientación.
hl.bind(mainMod .. " + ALT + J", layout_actions.bind(actions.rotate_split, { name = "Rotar división" }), {
    description = "Sistema: Alternar división de ventana",
})

hl.bind(mainMod .. " + ALT + C", layout_actions.bind(actions.fit_center, { name = "Ajustar/centrar" }), {
    description = "Ventanas: Ajustar a la vista o centrar flotante",
})
