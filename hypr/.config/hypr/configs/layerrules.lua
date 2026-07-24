-- configs/layerrules.lua
hl.layer_rule({
    name = "launchers",
    match = { namespace = "^(rofi|walker)$" },
    blur = true,
    ignore_alpha = 0.5,
    animation = "popin 95%",
})

hl.layer_rule({
    name = "status-bar",
    match = { namespace = "^(bar)$" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "fade",
})

hl.layer_rule({
    name = "logout-menu",
    match = { namespace = "logout_dialog" },
    blur = true,
    animation = "fade",
    ignore_alpha = 0.5,
})
hl.layer_rule({
  name = "wallpaper-menu",
  match = {namespace = "wallpaper-menu"},
  animation = "fade"
})
hl.layer_rule({
    name = "osd-visuals",
    match = { namespace = "^(swayosd)$" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "notification-center",
    match = { namespace = "swaync-notification-window" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "dashboard",
    match = { namespace = "dashboard" },
    animation = "slide left",
    blur = false,
})

hl.layer_rule({ match = { namespace = "swaync-control-center" }, ignore_alpha = 0.5, blur = true })
hl.layer_rule({ match = { namespace = "notification-panel" }, ignore_alpha = 0.5, blur = true })
hl.layer_rule({ match = { namespace = "notification-popups" }, ignore_alpha = 0.5, blur = true })
