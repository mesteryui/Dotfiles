hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("qs ipc call ui.powermenu togglePowerMenu"), { description = "Menú de salida" })
hl.bind(mainMod .. " + F1", helper.gamemode.toggle, { description = "Alternar modo juego" })
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(menu_layout_changer), { description = "Cambiar distribución de teclado" })
hl.bind("ALT + L", hl.dsp.exec_cmd("hyprlock"), { description = "Bloquear pantalla" })
hl.bind("ALT + C", hl.dsp.exec_cmd("qs ipc call notifications dndToggle"), { description = "Alternar modo No Molestar" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle"), { description = "Alternar panel de notificaciones" })

hl.bind("ALT + N", hl.dsp.exec_cmd("uwsm app -- " .. bar_layout_selector), { description = "Selector de diseño de barra" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("launch-waybar"), { description = "Reiniciar Waybar" })

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Alternar pseudotiling" })
hl.bind(mainMod .. " + ALT + J", hl.dsp.layout("togglesplit"), { description = "Alternar división de ventana" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(wallpaper_selector), { description = "Selector de fondo de pantalla" })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Arrastrar ventana" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar ventana" })

hl.bind(mainMod .. " + ESCAPE", hl.dsp.submap("Passthrough"), { description = "Entrar al submapa Passthrough" })
