-- configs/rules_windows/packettracer.lua
-- Cisco Packet Tracer: app Qt via XWayland. Todo flotante, como en un WM
-- clasico: sus submenus tienen class/title/pid IDENTICOS a la principal
-- (verificado con hyprctl), asi que ninguna regla estatica puede
-- distinguirlos. Flotando todo, cada ventana aparece donde le corresponde.

local ptClass = "^(PacketTracer|packettracer)$"

-- Base: todo PT flota; ignorar maximize (rompe el layout).
hl.window_rule({
    name = "packettracer-base",
    match = { class = ptClass },
    float = true,
    suppress_event = "maximize",
})

-- Ventana principal: flotante a tamaño natural (NO forzar size/center aqui:
-- los submenus comparten class/title con ella y heredarian ese tamaño).
-- Anti-parpadeo: opacidad 1.0 override, opaca, sin blur/shadow/rounding.
hl.window_rule({
    name = "packettracer-main",
    match = { class = ptClass, title = "^Cisco Packet Tracer$" },
    focus_on_activate = true,
    opacity = "1.0 override 1.0 override 1.0 override",
    opaque = true,
    force_rgbx = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    rounding = 0,
})

-- Ventanas auxiliares (submenus, desplegables, tooltips, combos):
-- flotar en su posicion natural, SIN centrar ni redimensionar.
hl.window_rule({
    name = "packettracer-aux",
    match = { class = ptClass, title = "negative:^Cisco Packet Tracer$" },
    opacity = "1.0 override 1.0 override 1.0 override",
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    rounding = 0,
})

-- Solo los dialogos grandes conocidos se centran con tamaño fijo.
hl.window_rule({
    name = "packettracer-dialog",
    match = {
        class = ptClass,
        title = "^(.*Save.*|.*Open.*|.*Login.*|.*Preferences.*|.*Configuration.*|.*Settings.*|Activity Wizard.*)$",
    },
    center = true,
    size = { 1100, 700 },
})
