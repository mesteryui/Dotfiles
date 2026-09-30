hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Apps: Ejecutar la terminal" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager), { description = "Apps: Abrir el gestor de archivos" })
hl.bind("ALT + SPACE", hl.dsp.exec_cmd(menu), { description = "Apps: Abrir menu" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(system_menu), { description = "Apps: Abrir menú del sistema" })
hl.bind(
	"ALT + K",
	hl.dsp.global("quickshell:cheatsheetToggle"),
	{ description = "Sistema: Abrir descriptor de los atajos de teclas" }
)
hl.bind(
	"ALT + P",
	hl.dsp.exec_cmd("hyprpicker --autocopy"),
	{ description = "Apps: Seleccionar un color y copiar al portapapeles" }
)
hl.bind(
	mainMod .. " + C",
	hl.dsp.exec_cmd("qs ipc call dashboard toggle"),
	{ description = "Apps: Abrir el panel de control y recursos" }
)
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), { description = "Apps: Abrir el navegador web" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(emacs), { description = "Apps: Abrir GNU Emacs" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("Telegram"), { description = "Apps: Abrir Telegram" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("equibop"), { description = "Apps: Abrir Vesktop (Discord)" })
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("zapzap"), { description = "Apps: Abrir ZapZap (WhatsApp)" })

hl.bind("ALT + V", hl.dsp.exec_cmd(clipboard_menu), { description = "Apps: Abrir gestor de portapapeles" })
hl.bind("ALT + E", hl.dsp.exec_cmd(emoji_menu), { description = "Apps: Abrir selector de emojis" })
--hl.bind("ALT + F", hl.dsp.exec_cmd(files_menu), { description = "Apps: Buscar archivos" })
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("cartridges"), { description = "Apps: Abrir Cartridges (juegos)" })
