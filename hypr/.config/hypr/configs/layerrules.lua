-- configs/layerrules.lua
-- El launcher abre/cierra por animación QML: suprimir la del compositor
-- evita doble movimiento (patrón Ryoku: launcher-noanim).
hl.layer_rule({
	name = "launchers",
	match = { namespace = "^(rofi|walker|quickshell:launcher)$" },
	blur = true,
	ignore_alpha = 0.5,
	animation = "popin 95%",
})

hl.layer_rule({
	name = "status-bar",
	match = { namespace = "^(quickshell:bar)$" },
	blur = true,
	ignore_alpha = 0.5,
	no_anim = true,
	--animation = "fade",
})

hl.layer_rule({
	name = "logout-menu",
	match = { namespace = "quickshell:logout_dialog" },
	blur = true,
	animation = "fade",
	ignore_alpha = 0.5,
})

hl.layer_rule({
	name = "polkit",
	match = { namespace = "quickshell:polkitDialog" },
	blur = true,
	ignore_alpha = 0.5,
})

hl.layer_rule({
	name = "wallpaper-menu",
	match = { namespace = "quickshell:wallpaper-menu" },
	no_anim = true,
})
hl.layer_rule({
	name = "osd-visuals",
	match = { namespace = "^(swayosd.*|quickshell:osd.*)$" },
	no_anim = true,
	blur = true,
	ignore_alpha = 0.5,
})

hl.layer_rule({
	name = "notification-center",
	match = { namespace = "quickshell:notification-center" },
	no_anim = true,
	blur = true,
	ignore_alpha = 0.5,
})

hl.layer_rule({ name = "wallpaper", match = { namespace = "quickshell:wallpaper-layer" }, animation = "fade" })

hl.layer_rule({
	name = "notification-popups",
	match = { namespace = "quickshell:notifications" },
	no_anim = true,
	blur = true,
	ignore_alpha = 0.5,
})

hl.layer_rule({
	name = "cheatsheet",
	match = { namespace = "quickshell:cheatsheet" },
	blur = true,
	ignore_alpha = 0.5,
	animation = "slide down",
})

hl.layer_rule({
	name = "quickshell-default",
	match = { namespace = "^(quickshell)$" },
	blur = true,
	ignore_alpha = 0.5,
	animation = "popin 95%",
})

hl.layer_rule({
	name = "window-switcher",
	match = { namespace = "quickshell:window-switcher" },
	blur = true,
	ignore_alpha = 0.5,
	no_anim = true,
})

hl.layer_rule({
	name = "screen-rounding",
	match = { namespace = "^quickshell:(border-.*|connect-.*)$" },
	no_anim = true,
	blur = false,
})

hl.layer_rule({
	name = "dashboard",
	match = { namespace = "quickshell:dashboard" },
	animation = "slide left",
	blur = false,
})
