hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("uwsm app -- " .. terminal), { description = "Ejecutar la terminal" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("uwsm app -- " .. fileManager), { description = "Abrir el gestor de archivos" })
hl.bind("ALT + SPACE", hl.dsp.exec_cmd("uwsm app -- " .. menu), { description = "Abrir menu" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("uwsm app -- " .. system_menu), { description = "Abrir menú del sistema" })
hl.bind("ALT + K", hl.dsp.exec_cmd("uwsm app -- menubinds.sh"),
    { description = "Abrir descriptor de los atajos de teclas" })
hl.bind("ALT + P", hl.dsp.exec_cmd("uwsm app -- hyprpicker --autocopy"),
    { description = "Seleccionar un color y copiar al portapapeles" })

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("uwsm app -- " .. browser), { description = "Abrir el navegador web" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("uwsm app -- " .. emacs), { description = "Abrir GNU Emacs" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("uwsm app -- Telegram"), { description = "Abrir Telegram" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("uwsm app -- vesktop"), { description = "Abrir Vesktop (Discord)" })
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("uwsm app -- zapzap"), { description = "Abrir ZapZap (WhatsApp)" })

hl.bind("ALT + V", hl.dsp.exec_cmd("uwsm app -- " .. clipboard_menu), { description = "Abrir gestor de portapapeles" })
hl.bind("ALT + E", hl.dsp.exec_cmd("uwsm app -- " .. emoji_menu), { description = "Abrir selector de emojis" })
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("uwsm app -- cartridges"), { description = "Abrir Cartridges (juegos)" })
