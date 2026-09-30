hl.bind(
	mainMod .. " + SHIFT + E",
	hl.dsp.exec_cmd("qs ipc call ui.powermenu togglePowerMenu"),
	{ description = "Sistema: Menú de salida" }
)
hl.bind(
	mainMod .. " + F1",
	hl.dsp.global("quickshell:toggle_gamemode"),
	{ description = "Sistema: Alternar modo juego" }
)
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(menu_layout_changer), { description = "Sistema: Abrir menú principal" })
hl.bind("ALT + L", hl.dsp.global("quickshell:lock"), { description = "Sistema: Bloquear pantalla" })
hl.bind("Caps_Lock", hl.dsp.global("quickshell:capsLock"), { locked = true })
--hl.bind()
hl.bind(
	"ALT + N",
	hl.dsp.exec_cmd("qs ipc call notifications dndToggle"),
	{ description = "Sistema: Alternar modo No Molestar" }
)
hl.bind(
	mainMod .. " + N",
	hl.dsp.exec_cmd("qs ipc call notifications toggle"),
	{ description = "Sistema: Alternar panel de notificaciones" }
)

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Sistema: Alternar pseudotiling" })
hl.bind(
	mainMod .. " + ALT + J",
	hl.dsp.layout("togglesplit"),
	{ description = "Sistema: Alternar división de ventana" }
)
hl.bind(
	mainMod .. " + W",
	hl.dsp.global("quickshell:wallpaperSelectorToggle"),
	{ description = "Sistema: Selector de fondo de pantalla" }
)

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Sistema: Arrastrar ventana" })
hl.bind(
	mainMod .. " + mouse:273",
	hl.dsp.window.resize(),
	{ mouse = true, description = "Sistema: Redimensionar ventana" }
)

hl.bind(mainMod .. " + A", hl.dsp.global("quickshell:audio_panel"))

hl.bind(
	mainMod .. " + ESCAPE",
	hl.dsp.submap("Passthrough"),
	{ description = "Submapas: Entrar al submapa Passthrough" }
)
