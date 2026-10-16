-- =============================================================================
-- CAELESTIA SPRING - Hyprland Motion Profile
-- Base: caelestia.lua + end-4.lua, física: springs MD3 de Image 1.
-- Adapta speeds antiguos (fade 6 = 600ms, workspaces 7 = 700ms -> lentos)
-- a filosofía viva no obstructiva: movimiento 220-320ms, fade/borde <=150ms.
-- Prefijo cs_ para no colisionar con caelestia/end-4/shinro si se cargan juntos.
-- speed = decasegundos: 1 = 100ms.
-- =============================================================================

-- 1. Springs espaciales (Image 1, líneas 1-3) — ventanas, workspaces
hl.curve("cs_spatial_fast", { type = "spring", mass = 1, stiffness = 600, dampening = 49 })
hl.curve("cs_spatial_default", { type = "spring", mass = 1, stiffness = 300, dampening = 30 })
hl.curve("cs_spatial_slow", { type = "spring", mass = 1, stiffness = 160, dampening = 25 })
-- Rebote dedicado para apertura: subamortiguado (ratio ~0.65) con overshoot corto.
-- 3ms literales son <1 frame (16.6ms a 60Hz) y la granularidad de Hyprland es 100ms,
-- así que se implementa como micro-rebote visible de ~30-50ms dentro de los 320ms totales.
hl.curve("cs_windowsIn_bounce", { type = "spring", mass = 1, stiffness = 280, dampening = 22 })

-- 2. Springs de efectos (Image 1, líneas 7-9, ratio 1.0 = sin rebote) — fade, bordes
hl.curve("cs_effects_fast", { type = "spring", mass = 1, stiffness = 3800, dampening = 123 })
hl.curve("cs_effects_default", { type = "spring", mass = 1, stiffness = 1600, dampening = 80 })
hl.curve("cs_effects_slow", { type = "spring", mass = 1, stiffness = 800, dampening = 57 })

-- 3. Beziers heredados de caelestia (solo layers Quickshell, sin temblor elástico)
hl.curve("cs_standard", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })
hl.curve("cs_emphasized_accel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })
hl.curve("cs_linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })

-- 2. Animations (estructura caelestia + splits end-4 + springs Image 1)

-- Windows (caelestia no tenía parent ni popin; se añade de Image 1 / end-4)
hl.animation({ leaf = "windows", enabled = true, speed = 3, spring = "cs_spatial_default" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, spring = "cs_windowsIn_bounce", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, spring = "cs_spatial_fast", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "cs_spatial_default", style = "slide" })

-- Layers Quickshell (caelestia usaba slide; Image 1 usaba fade — se conserva slide
-- para barras, fade solo como parent heredable)
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "cs_standard", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "cs_standard", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "cs_emphasized_accel", style = "slide" })
-- caelestia tenía fadeLayers parent (speed 5 = 500ms, lento); end-4 lo divide en
-- In/Out. Se dan los tres, ya corregidos a <=150ms con effects_default.
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 1.5, spring = "cs_effects_default" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.5, spring = "cs_effects_default" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, spring = "cs_effects_default" })

-- Workspaces (caelestia speed 5 = 500ms, end-4 speed 7 = 700ms -> ambos lentos,
-- se baja a 3.2 ~= 320ms con spring vivo)
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, spring = "cs_spatial_default", style = "slide" })
-- caelestia: parent slidefadevert 15%. end-4: split In/Out slidevert. Se dan los tres.
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, spring = "cs_spatial_slow", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.8, spring = "cs_spatial_slow", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.2, spring = "cs_spatial_fast", style = "slidevert" })

-- Fades (caelestia speed 6 = 600ms -> ralentiza percepción; se baja a 1.5 ~= 150ms,
-- sin rebote con effects_default)
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, spring = "cs_effects_default" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.5, spring = "cs_effects_default" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, spring = "cs_effects_default" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.5, spring = "cs_effects_default" })

-- Bordes (caelestia 6 = 600ms, end-4 10 = 1000ms -> ambos obstruyen; 1.5 sin rebote)
hl.animation({ leaf = "border", enabled = true, speed = 1.5, spring = "cs_effects_fast" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "cs_linear", style = "loop" })

-- Extra de end-4 (caelestia no lo tenía)
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, spring = "cs_effects_default" })
