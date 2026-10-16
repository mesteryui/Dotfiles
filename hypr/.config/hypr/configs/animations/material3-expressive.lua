-- =============================================================================
-- MATERIAL 3 EXPRESSIVE - Hyprland Motion Profile
-- Springs oficiales M3 Expressive (Compose MotionScheme) + tus params Image 1.
-- Mapeo dampingRatio -> Hyprland: dampening = ratio * 2 * sqrt(stiffness), mass = 1.
--
--  Expressive default spatial: ratio 0.8, k 380 -> c ~= 31 (vivo, overshoot)
--  Expressive fast spatial:    ratio 0.6, k 800 -> c ~= 34 (hero, bounce marcado)
--  Expressive slow spatial:    ratio 0.8, k 200 -> c ~= 23 (gentle, overlays)
--  Effects fast/default/slow: ratio 1.0, k 3800/1600/800 -> c 123/80/57
--   (= idénticos a tu Image 1: ya eran los tokens M3 effects, se reutilizan tal cual)
--
-- Duraciones M3 (fast 150ms, medium 250ms, slow 400ms) -> Hyprland speed 1.5/2.5/4.
-- Prefijo m3e_ para no colisionar con shinro/cs_/caelestia/end-4.
-- =============================================================================

-- 1. Springs espaciales M3 Expressive (movimiento: ventanas, workspaces)
hl.curve("m3e_spatial_fast", { type = "spring", mass = 1, stiffness = 800, dampening = 34 })
hl.curve("m3e_spatial_default", { type = "spring", mass = 1, stiffness = 380, dampening = 31 })
hl.curve("m3e_spatial_slow", { type = "spring", mass = 1, stiffness = 200, dampening = 23 })

-- 2. Springs de efectos M3 (= tus params Image 1, ratio 1.0 sin rebote)
hl.curve("m3e_effects_fast", { type = "spring", mass = 1, stiffness = 3800, dampening = 123 })
hl.curve("m3e_effects_default", { type = "spring", mass = 1, stiffness = 1600, dampening = 80 })
hl.curve("m3e_effects_slow", { type = "spring", mass = 1, stiffness = 800, dampening = 57 })

-- 3. Beziers: solo layers Quickshell y loops. Los springs espaciales M3 son
-- a propósito rebotones (ratio 0.6-0.8); en una barra harían temblar el panel.
-- Se usa el equivalente web M3 sin overshoot para layers.
hl.curve("m3e_layers", { type = "bezier", points = { { 0.34, 0.80 }, { 0.34, 1.0 } } })
hl.curve("m3e_accel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })
hl.curve("m3e_linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })

-- 2. Animations

-- Windows: In con fast (bounce expressive hero), Move default, Out default corto
-- (mismo spring que In pero truncado por speed 2.2: cierra rápido sin cola elástica).
hl.animation({ leaf = "windows", enabled = true, speed = 3, spring = "m3e_spatial_default" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, spring = "m3e_spatial_fast", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, spring = "m3e_spatial_default", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "m3e_spatial_default", style = "slide" })

-- Layers Quickshell: bézier sin rebote (ver nota arriba).
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "m3e_layers", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "m3e_layers", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "m3e_accel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 1.5, spring = "m3e_effects_default" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.5, spring = "m3e_effects_default" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, spring = "m3e_effects_default" })

-- Workspaces: default con inercia, special con slow gentle.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, spring = "m3e_spatial_default", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, spring = "m3e_spatial_slow", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.8, spring = "m3e_spatial_slow", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.2, spring = "m3e_spatial_default", style = "slidevert" })

-- Fades y bordes: effects ratio 1.0, <=150ms.
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, spring = "m3e_effects_default" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.5, spring = "m3e_effects_default" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, spring = "m3e_effects_default" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.5, spring = "m3e_effects_default" })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, spring = "m3e_effects_fast" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "m3e_linear", style = "loop" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, spring = "m3e_effects_default" })
