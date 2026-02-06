Name="hyprland-animations"
NamePretty="Hyprland Animations"
function ApplyAnimation(val)
    local archivo = ObtenerHyprAnimsLayoutDir().."../animation.conf"
end
function ObtenerHyprAnimsLayoutDir()
    local dir = os.getenv("XDG_CONFIG_HOME")
    if dir then
	return dir .. "/hypr/configs/animations/"
    else
	return os.getenv("HOME") .. "/.config/hypr/configs/animations/"
    end
end
function EliminarExtension(line)
    return line:match("(.+)%..+$") or line
end
function GetEntries()
    local entries = {}
    local dir = ObtenerHyprAnimsLayoutDir()
    local handle = io.popen('find "' .. dir .. '" -maxdepth 1 -type f -printf "%f\n"')
    if handle then
        for line in handle:lines() do
	    local name = EliminarExtension(line)
	    local nombre = name:gsub("^%l",string.upper):gsub("-"," ")
	    table.insert(entries,{
		Text = nombre,
		Value = line,
		Actions = { apply_animation = "lua:ApplyAnimation" }
	    })
	end
    end
    return entries
end
