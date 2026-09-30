-- =============================================================================
-- SHINRO SHELL (進路) - Hyprland Motion Profile
-- Concept: Precision, Smooth Deceleration & Firm Motion
-- =============================================================================

-- 1. Curves (Curvas Bézier)
-- Emphasized Decel: Entrada suave pero decidida (snappy start, settling finish)
hl.curve("shinroDecel", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })

-- Emphasized Accel: Salidas ultra rápidas para eliminar latencia percibida
hl.curve("shinroAccel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })

-- Standard / Workspace: Transiciones continuas sin oscilaciones
hl.curve("shinroStandard", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })

-- Fast Exit: Para fades y capas que deben desaparecer de inmediato
hl.curve("shinroSharp", { type = "bezier", points = { { 0.4, 0.0 }, { 1.0, 1.0 } } })


-- 2. Animation Setups

-- Layers (Quickshell Panels, Popups & Bars)
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "shinroDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "shinroAccel", style = "slide" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 4, bezier = "shinroDecel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.5, bezier = "shinroSharp" })

-- Windows (Tiling & Floating Windows)
-- Pop-in sutil con escala ligera para aperturas táctiles y precisas
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "shinroDecel", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "shinroAccel", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "shinroStandard" })

-- Workspaces & Spatial Navigation
-- Desplazamiento horizontal para escritorios principales
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "shinroStandard", style = "slide" })

-- Special Workspace (Scratchpad / Overlay Panel)
-- Entra desde arriba/abajo con un ligero fade vertical
hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 3.5,
    bezier  = "shinroDecel",
    style   = "slidefadevert 20%"
})

-- Fades & Transitions
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "shinroStandard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 4, bezier = "shinroStandard" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "shinroStandard" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 6, bezier = "shinroStandard" })
