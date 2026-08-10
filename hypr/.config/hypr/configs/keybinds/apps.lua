hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Ejecutar la terminal" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager), { description = "Abrir el gestor de archivos" })
hl.bind("ALT + SPACE", hl.dsp.exec_cmd(menu), { description = "Abrir menu" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(system_menu), { description = "Abrir menú del sistema" })
hl.bind("ALT + K", hl.dsp.exec_cmd("qs ipc call cheatsheet toggle"),
    { description = "Abrir descriptor de los atajos de teclas" })
hl.bind("ALT + P", hl.dsp.exec_cmd("hyprpicker --autocopy"),
    { description = "Seleccionar un color y copiar al portapapeles" })

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), { description = "Abrir el navegador web" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(emacs), { description = "Abrir GNU Emacs" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("Telegram"), { description = "Abrir Telegram" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("vesktop"), { description = "Abrir Vesktop (Discord)" })
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("zapzap"), { description = "Abrir ZapZap (WhatsApp)" })

hl.bind("ALT + V", hl.dsp.exec_cmd(clipboard_menu), { description = "Abrir gestor de portapapeles" })
hl.bind("ALT + E", hl.dsp.exec_cmd(emoji_menu), { description = "Abrir selector de emojis" })
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("cartridges"), { description = "Abrir Cartridges (juegos)" })
