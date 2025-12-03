Name = "waybar-layout-selector"
NamePretty = "Waybar layouts"
FixedOrder = true
Action = "lua:GuardarLayoutReinciar"
HideFromProviderlist = true
SearchName = true

function crear_directorio_si_no_existe(path)
    -- path solo del directorio
    os.execute("mkdir -p " .. path)
end

function SaberArchivo()
    local base
    if os.getenv("XDG_CACHE_HOME") then
	base = os.getenv("XDG_CACHE_HOME")
    else
	base = os.getenv("HOME") .. "/.cache"
    end
    crear_directorio_si_no_existe(base .. "/hyprsphere")
    return base .."/hyprsphere/waybar-layout.txt"
end
function ObtenerLayoutActual()
    local archivo = SaberArchivo()
    local file = io.open(archivo,"r")
    if file then
	x = file:read("*l")
	file:close()
	return x
    end
    return nil
end
function ObtenerLayouts()
    local base
    if os.getenv("XDG_CONFIG_HOME") then
	base = os.getenv("XDG_CONFIG_HOME")
    else
	base = os.getenv("HOME") .. "/config"
    end
    return base .. "/waybar/layouts"
end
function GetEntries()
    local entries = {}
    local layout_dir = ObtenerLayouts()
    local handle = io.popen("ls " .. layout_dir)
    local current_layout = ObtenerLayoutActual()
    if handle then
        for line in handle:lines() do
	    line = line:gsub("\n","")
            -- Usa solo el nombre del archivo, quita extensiones si quieres
	    local primera_mayuscula = line:find("%u", 2) -- busca mayúscula después del primer carácter
            local nombre
            if primera_mayuscula then
                nombre = line:sub(1, primera_mayuscula - 1) .. " " .. line:sub(primera_mayuscula)
            else
                nombre = line -- si no hay mayúscula después de la primera, deja el nombre igual
            end
            nombre = nombre:gsub("^%l", string.upper) -- mayúscula inicial si lo deseas
	    if line == current_layout then
		table.insert(entries,{
		    Text = nombre,
		    Subtext = "Current", 
		    Value = line,
		})
	    else
		table.insert(entries, {
                    Text = nombre,
                    Value = line,
		})
		end
        end
        handle:close()
	if #entries == 0 then
	    table.insert(entries,{
		Text = "No hay layouts disponibles",
		Value = "",
	    })
	end
    end
    return entries
end

function GuardarLayoutReinciar(layout)
    local archivo = SaberArchivo()
    local file = io.open(archivo,"w")
    if file then
	file:write(layout)
	file:close()
	os.execute("notify-send 'Cambio de Layout' 'Layout cambiado a: " .. layout .. "'")
	os.execute("launch-waybar")
    else
	os.execute("notify-send 'No se pudo cambiar el layout'")
    end
end
