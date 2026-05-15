-- configs/keybinds.lua
--hl.bind(mainMod .. " + O", "dispatcher:hyprexpo:expo, toggle")
local workspaces = 10
for i = 1, workspaces do
    local key = i % workspaces
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Moverse al espacio de trabajo " ..
    i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
        { description = "Mover ventana al espacio de trabajo " .. i })
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Alternar espacio de trabajo especial" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Mover ventana al espacio de trabajo especial" })

hl.bind(mainMod .. " + CONTROL + RIGHT", hl.dsp.focus({ workspace = "r+1" }), { description = "Siguiente espacio de trabajo" })
hl.bind(mainMod .. " + CONTROL + LEFT", hl.dsp.focus({ workspace = "r-1" }), { description = "Anterior espacio de trabajo" })

-- Apps
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

-- Media
local osd_client = "swayosd-client"
hl.bind("XF86AUDIORAISEVOLUME", hl.dsp.exec_cmd(osd_client .. " --output-volume=raise"),
    { repeating = true, description = "Subir volumen" })
hl.bind("XF86AUDIOLOWERVOLUME", hl.dsp.exec_cmd(osd_client .. " --output-volume=lower"),
    { repeating = true, description = "Bajar volumen" })
hl.bind("XF86AUDIOMUTE", hl.dsp.exec_cmd(osd_client .. " --output-volume=mute-toggle"), { description = "Silenciar audio" })
hl.bind("XF86AUDIOMICMUTE", hl.dsp.exec_cmd(osd_client .. " --input-volume=mute-toggle"),
    { description = "Silenciar micrófono" })
hl.bind("XF86MONBRIGHTNESSUP", hl.dsp.exec_cmd(osd_client .. " --brightness=raise"),
    { repeating = true, description = "Subir brillo" })
hl.bind("XF86MONBRIGHTNESSDOWN", hl.dsp.exec_cmd(osd_client .. " --brightness=lower"),
    { repeating = true, description = "Bajar brillo" })

hl.bind(mainMod .. " + I", hl.dsp.submap("Multimedia"), { description = "Entrar al submapa Multimedia" })
local function screenshot_active_monitor()
    local active_mon = hl.get_active_monitor()
    local mon = active_mon and active_mon.name and active_mon.name ~= DefaultMonitor and active_mon.name or DefaultMonitor
    
    hl.exec_cmd("hyprshot -m output -m " .. mon)
end
hl.bind("PRINT", screenshot_active_monitor, { description = "Captura de pantalla del monitor activo" })
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename -"),
    { description = "Captura de pantalla de región" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("walker -m menus:screenshot"), { description = "Abrir menú de capturas" })

require("configs.some_funcs")

-- System
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("wlogout -b 5"), { description = "Menú de salida" })
--hl.bind(mainMod .. " + F1",         hl.dsp.exec_cmd("bash -c \"toggle-gamemode.sh\""))
hl.bind(mainMod .. " + F1", Toggle_gamemode, { description = "Alternar modo juego" })
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(menu_layout_changer), { description = "Cambiar distribución de teclado" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"), { description = "Bloquear pantalla" })
hl.bind("ALT + C", hl.dsp.exec_cmd("swaync-client --toggle-dnd"), { description = "Alternar modo No Molestar" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client --toggle-panel"), { description = "Alternar panel de notificaciones" })

hl.bind("ALT + N", hl.dsp.exec_cmd("uwsm app -- " .. bar_layout_selector), { description = "Selector de diseño de barra" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("launch-waybar"), { description = "Reiniciar Waybar" })

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Alternar pseudotiling" })
hl.bind(mainMod .. " + ALT + J", hl.dsp.layout("togglesplit"), { description = "Alternar división de ventana" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(wallpaper_selector), { description = "Selector de fondo de pantalla" })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Arrastrar ventana" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar ventana" })

hl.bind(mainMod .. " + ESCAPE", hl.dsp.submap("Passthrough"), { description = "Entrar al submapa Passthrough" })

-- Windows
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close(), { description = "Cerrar ventana" })

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Alternar flotado" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { description = "Alternar pantalla completa" })
hl.bind("ALT + TAB", hl.dsp.exec_cmd("sleep 0.5;snappy-switcher toggle"), { description = "Cambiar entre aplicaciones" })
hl.bind(mainMod .. " + F12", function()
    if not hl.plugin or not hl.plugin.hyprbars then
        hl.notification.create({
            text = "Error: El plugin hyprbars no está cargado",
            timeout = 3000,
            color = Colors.error
        })
        return -- Rompe la ejecución de forma segura
    end
    local pl_key = "plugin.hyprbars.enabled"
    local is_enabled = hl.get_config(pl_key)
    if is_enabled then
        hl.config({ [pl_key] = false})
    else
        hl.config({ [pl_key] = true })
    end
end, { description = "Alternar hyprbars" })

hl.bind(mainMod.." + O", function ()
    if hl.plugin and hl.plugin.hyprexpo then
        hl.plugin.hyprexpo.expo("toggle")
    end
end, {description = "Abrir/Cerrar Hyprexpo (aun no funciona)"})
-- Focus & Move
local movement = {
    { dir = "left",  nombre = "izquierda", teclas = { "H", "LEFT" } },
    { dir = "right", nombre = "derecha",   teclas = { "L", "RIGHT" } },
    { dir = "up",    nombre = "arriba",    teclas = { "K", "UP" } },
    { dir = "down",  nombre = "abajo",     teclas = { "J", "DOWN" } }
}

for _, item in ipairs(movement) do
    for _, key in ipairs(item.teclas) do
        -- Foco de ventana
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = item.dir }),
            { description = "Cambiar foco a la " .. item.nombre })

        -- Mover ventana
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = item.dir }),
            { description = "Mover ventana hacia la " .. item.nombre })
    end
end

hl.bind("ALT + R", hl.dsp.submap("resize"), { description = "Entrar al submapa de redimensionamiento" })
