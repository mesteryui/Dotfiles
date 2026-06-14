hl.bind("XF86AUDIORAISEVOLUME", hl.dsp.exec_cmd("uwsm app -- wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0"),
    { repeating = true, description = "Subir volumen" })
hl.bind("XF86AUDIOLOWERVOLUME", hl.dsp.exec_cmd("uwsm app -- wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- -l 1.0"),
    { repeating = true, description = "Bajar volumen" })
hl.bind("XF86AUDIOMUTE", hl.dsp.exec_cmd("uwsm app -- wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { description = "Silenciar audio" })
hl.bind("XF86AUDIOMICMUTE", hl.dsp.exec_cmd("uwsm app -- wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { description = "Silenciar micrófono" })
hl.bind("XF86MONBRIGHTNESSUP", hl.dsp.exec_cmd("uwsm app -- qs ipc call brightness increment 5"),
    { repeating = true, description = "Subir brillo" })
hl.bind("XF86MONBRIGHTNESSDOWN", hl.dsp.exec_cmd("uwsm app -- qs ipc call brightness decrement 5"),
    { repeating = true, description = "Bajar brillo" })

hl.bind(mainMod .. " + I", hl.dsp.submap("Multimedia"), { description = "Entrar al submapa Multimedia" })

local function screenshot_active_monitor()
    local active_mon = hl.get_active_monitor()
    local mon = (active_mon and active_mon.name and active_mon.name ~= DefaultMonitor) and active_mon.name or DefaultMonitor
    
    hl.exec_cmd("uwsm app -- hyprshot -m output -m " .. mon)
end
hl.bind("PRINT", screenshot_active_monitor, { description = "Captura de pantalla del monitor activo" })
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("uwsm app -- hyprshot -m region --raw | satty --filename -"),
    { description = "Captura de pantalla de región" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("uwsm app -- walker -m menus:screenshot"), { description = "Abrir menú de capturas" })

