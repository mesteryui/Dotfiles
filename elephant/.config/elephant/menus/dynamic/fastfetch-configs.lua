Name="fastfetch"
Action="lua:CambiarLayout"
NamePretty = "Fastfetch Themes layouts"
HideFromProviderlist = true
FixedOrder = true

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
    if handle then
	for line in handle:lines() do
	    local name = EliminarExtension(line)
	    local nombre = name:gsub("^%l",string.upper):gsub("-"," ")
	    table.insert(entries,{
		Text = nombre,
		Value = line,
	    })
	end
	handle:close()
    end
    if #entries == 0 then
	    table.insert(entries,{
		Text = "No hay layouts disponibles",
		Value = "",
	    })
	end
    return entries
end
