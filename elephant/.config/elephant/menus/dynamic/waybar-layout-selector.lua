Name = "waybar-layout-selector"
NamePretty = "Waybar layouts"
FixedOrder = true
Action = "lua:GuardarLayoutReinciar"
HideFromProviderlist = true
SearchName = true

function crear_directorio_si_no_existe(path)
    os.execute("mkdir -p " .. path)
end

function ObtenerLayoutActual()
    local waybar_dir = ObtenerDirectorioWaybar()
    local handle = io.popen("readlink -f " .. waybar_dir .. "config.jsonc 2>/dev/null")
    local resultado = handle:read("*a")
    handle:close()
    
    if resultado == "" then
        return nil
    end
    
    local layout_name = resultado:match("layouts/([^/]+)/config.jsonc")
    return layout_name
end

function ObtenerDirectorioWaybar()
    local base
    if os.getenv("XDG_CONFIG_HOME") then
        base = os.getenv("XDG_CONFIG_HOME")
    else
        base = os.getenv("HOME") .. "/.config"
    end
    return base .. "/waybar/"
end

function GetEntries()
    local entries = {}
    local waybar_dir = ObtenerDirectorioWaybar()
    local layout_dir = waybar_dir .. "layouts"
    local current_layout = ObtenerLayoutActual()
    
    local handle = io.popen("ls -d " .. layout_dir .. "/*/ 2>/dev/null")
    
    if handle then
        for line in handle:lines() do
            -- Extrae solo el nombre del directorio
            local layout_name = line:match("([^/]+)/$")
            
            if layout_name then
                -- Formatea el nombre (ej: dark → Dark, darkBlue → Dark Blue)
                local nombre = layout_name:gsub("^%l", string.upper)
                primera_mayuscula = nombre:find("%u", 2)
                if primera_mayuscula then
                    nombre = nombre:sub(1, primera_mayuscula - 1) .. " " .. nombre:sub(primera_mayuscula)
                end
                
                if layout_name == current_layout then
                    table.insert(entries, {
                        Text = nombre,
                        Subtext = "Current",
                        Value = layout_name,
                    })
                else
                    table.insert(entries, {
                        Text = nombre,
                        Value = layout_name,
                    })
                end
            end
        end
        handle:close()
        
        if #entries == 0 then
            table.insert(entries, {
                Text = "No hay layouts disponibles",
                Value = "",
            })
        end
    end
    
    return entries
end

function GuardarLayoutReinciar(layout)
    if layout == "" or layout == nil then
        return
    end
    
    local waybar_dir = ObtenerDirectorioWaybar()
    local layout_path = waybar_dir .. "layouts/" .. layout
    
    -- Crear symlinks
    os.execute("ln -sf " .. layout_path .. "/config.jsonc " .. waybar_dir .. "config.jsonc")
    os.execute("ln -sf " .. layout_path .. "/style.css " .. waybar_dir .. "style.css")
    
    -- Recargar waybar
    os.execute("systemctl restart --user waybar")
    
    -- Notificación
    os.execute("notify-send 'Cambio de Layout' 'Layout cambiado a: " .. layout .. "'")
end
