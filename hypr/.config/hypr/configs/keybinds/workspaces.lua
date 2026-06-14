local workspaces = 10
for i = 1, workspaces do
    local key = i % workspaces
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Moverse al espacio de trabajo " ..
    i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
        { description = "Mover ventana al espacio de trabajo " .. i })
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Alternar espacio de trabajo especial" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Mover ventana al espacio de trabajo especial" })

hl.bind(mainMod .. " + CONTROL + RIGHT", hl.dsp.focus({ workspace = "r+1" }), { description = "Siguiente espacio de trabajo" })
hl.bind(mainMod .. " + CONTROL + LEFT", hl.dsp.focus({ workspace = "r-1" }), { description = "Anterior espacio de trabajo" })
