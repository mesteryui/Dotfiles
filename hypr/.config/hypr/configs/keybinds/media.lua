hl.bind("XF86AUDIORAISEVOLUME", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0"),
    { repeating = true, description = "Multimedia: Subir volumen", locked = true })
hl.bind("XF86AUDIOLOWERVOLUME", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- -l 1.0"),
    { repeating = true, description = "Multimedia: Bajar volumen", locked = true })
hl.bind("XF86AUDIOMUTE", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { description = "Multimedia: Silenciar audio" })
hl.bind("XF86AUDIOMICMUTE", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { description = "Multimedia: Silenciar micrófono" })
hl.bind("XF86MONBRIGHTNESSUP", hl.dsp.exec_cmd("qs ipc call brightness increment 5"),
    { repeating = true, description = "Multimedia: Subir brillo", locked = true })
hl.bind("XF86MONBRIGHTNESSDOWN", hl.dsp.exec_cmd("qs ipc call brightness decrement 5"),
    { repeating = true, description = "Multimedia: Bajar brillo", locked = true })

hl.bind(mainMod .. " + I", hl.dsp.submap("Multimedia"), { description = "Submapas: Entrar al submapa Multimedia" })

local function screenshot_active_monitor()
    local active_mon = hl.get_active_monitor()
    local mon = (active_mon and active_mon.name and active_mon.name ~= DefaultMonitor) and active_mon.name or DefaultMonitor

    hl.exec_cmd("hyprshot -m output -m " .. mon)
end
hl.bind("PRINT", screenshot_active_monitor, { description = "Multimedia: Captura de pantalla del monitor activo" })
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m region --raw | tensaku --filename -"),
    { description = "Multimedia: Captura de pantalla de región" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd(screenshot_menu), { description = "Multimedia: Abrir menú de capturas" })

