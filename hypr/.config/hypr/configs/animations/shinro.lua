-- =============================================================================
-- SHINRO SHELL (進路) - Hyprland Motion Profile
-- Concept: Precision, Smooth Deceleration & Firm Motion
-- Filosofía: objeto físico con inercia — vivo pero no obstructivo.
-- Basado en ejemplo MD3 con springs reales (Image 1), adaptado a Shinro.
--
-- Física:
--  - mass = 1 siempre (recomendación Hyprland, solo ajustar stiffness/dampening)
--  - stiffness = velocidad. Más alto = más rápido.
--  - dampening = rebote. Ratio 1.0 = críticamente amortiguado (sin rebote).
--    ratio = dampening / (2 * sqrt(stiffness)). <1.0 = vivo con micro-rebote.
--
-- Tiempos (Hyprland speed = decasegundos: 1 = 100ms):
--  - Movimiento (windows/workspaces): speed 2.5-4 ~= 250-400ms, spring con rebote
--  - Opacidad/bordes (fade/border): speed 1-2 ~= 100-200ms, spring ratio 1.0 sin rebote
-- =============================================================================

-- 1. Springs espaciales (movimiento: ventanas, workspaces, Quickshell panels)
-- Rápido con micro-rebote (ratio ~0.81). Para salidas que deben desaparecer ya.
hl.curve("shinro_spatial_fast", { type = "spring", mass = 1, stiffness = 550, dampening = 38 })
-- Default: vivo con rebote sutil (ratio ~= 0.78). El principal.
hl.curve("shinro_spatial_default", { type = "spring", mass = 1, stiffness = 320, dampening = 28 })
-- Apertura con poquito bounce (ratio ~= 0.69). Solo para windowsIn popin.
hl.curve("shinro_pop", { type = "spring", mass = 1, stiffness = 300, dampening = 24 })
-- Lento con asentamiento suave (ratio ~0.82). Para specialWorkspace / overlays.
hl.curve("shinro_spatial_slow", { type = "spring", mass = 1, stiffness = 180, dampening = 22 })

-- 2. Springs de efectos (opacidad y bordes, ratio 1.0 = SIN rebote, ultra rápido)
hl.curve("shinro_effects_fast", { type = "spring", mass = 1, stiffness = 3800, dampening = 123 })
hl.curve("shinro_effects_default", { type = "spring", mass = 1, stiffness = 1600, dampening = 80 })

-- 3. Beziers solo para layers (barras Quickshell: slide lineal, sin física elástica
-- que las haría temblar) y para loops continuos.
hl.curve("shinro_standard", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })
hl.curve("shinro_emphasized_accel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })
hl.curve("shinro_linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })


-- 2. Animation Setups (como en Image 1: spring = "..." / bezier = "...")

-- Base (herencia para hijos no definidos)
hl.animation({ leaf = "windows", enabled = true, speed = 3, spring = "shinro_spatial_default" })

-- Windows: In con poquito bounce, Out rápido con micro-rebote, Move con inercia.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, spring = "shinro_pop", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, spring = "shinro_spatial_fast", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "shinro_spatial_default", style = "slide" })

-- Layers (Quickshell): slide físico al entrar, salida acelerada inmediata.
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "shinro_standard", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "shinro_standard", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "shinro_emphasized_accel", style = "slide" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.5, spring = "shinro_effects_default" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, spring = "shinro_effects_default" })

-- Workspaces: desplazamiento con inercia, vivo pero firme.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, spring = "shinro_spatial_default", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, spring = "shinro_spatial_slow", style = "slidefadevert 20%" })

-- Fades & Borders: críticamente amortiguados, sin rebote, <= ~150ms.
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, spring = "shinro_effects_default" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.5, spring = "shinro_effects_default" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, spring = "shinro_effects_default" })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, spring = "shinro_effects_fast" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "shinro_linear", style = "loop" })
