Name="fastfetch"
Action="lua:CambiarLayout"
NamePretty = "Fastfetch Themes layouts"
HideFromProviderlist = true
FixedOrder = true
Cache = false
function ObtenerNombreLayoutActual()
    local handle = io.popen("readlink "..ObtenerFastfetchLayoutDir().."../config.jsonc")
    local ruta = handle:read("*a"):gsub("%s+$","")
    handle:close()
    local nombre = ruta:match("([^/]+)$")
    return nombre
end

function ObtenerFastfetchLayoutDir()
    local dir = os.getenv("XDG_CONFIG_HOME")
    if dir then
	return dir .. "/fastfetch/layouts/"
    else
	return os.getenv("HOME") .. "/fastfetch/layouts/"
    end
end
function EliminarExtension(line)
    return line:match("(.+)%..+$") or line
end
function CambiarLayout(layout)
    local dir = ObtenerFastfetchLayoutDir()
    local nombre_layout = EliminarExtension(layout):gsub("^%l",string.upper):gsub("-"," ")
    local layout_quiero = dir..layout
    os.execute('ln -sf "' .. layout_quiero .. '" "' .. dir .. '../config.jsonc"')
    os.execute("notify-send 'Fastfetch Theme' 'Tema de fastfetch cambiado a: "..nombre_layout.."'")
end
function GetEntries()
    local entries = {}
    local dir = ObtenerFastfetchLayoutDir()
    local handle = io.popen('find "' .. dir .. '" -maxdepth 1 -type f -printf "%f\n"')
    local layout_actual = ObtenerNombreLayoutActual()
    if handle then
	for line in handle:lines() do
	    local name = EliminarExtension(line)
	    local nombre = name:gsub("^%l",string.upper):gsub("-"," ")
	    if layout_actual == line then
		table.insert(entries,{
		    Text = nombre,
		    Subtext = "Current",
		    Value = line,
		})
	    else
		table.insert(entries,{
		    Text = nombre,
		    Value = line,
		})
	    end
	end
	handle:close()
    end
    return entries
end
