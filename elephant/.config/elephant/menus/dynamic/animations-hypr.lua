Name = "hyprland-animations"
NamePretty = "Hyprland Animations"
Icon = ""
Description = "Menu de animacion"
FixedOrder = true
function ObtenerAnimacionActual()
	-- Usamos la función de ruta para ser consistentes
	local archivo_config = ObtenerHyprAnimsLayoutDir() .. "../animation.lua"

	-- Buscamos la línea 'require', extraemos lo que hay tras el último punto
	local comando = string.format("grep 'require(' \"%s\" | sed 's/.*\\.//;s/\").*//' | tr -d '[:space:]'", archivo_config)

	local handle = io.popen(comando)
	if handle then
		local resultado = handle:read("*a")
		handle:close()

		if resultado and resultado ~= "" then
			return resultado:gsub("%s+","")
		end
	end
	return ""
end
function ApplyAnimation(val)
	local name = EliminarExtension(val)
	local archivo = ObtenerHyprAnimsLayoutDir() .. "../animation.lua"
	-- Cambia lo que está después del último punto dentro del require
	local sed_cmd = string.format("sed -i 's|\\(require(\".*\\.\\)[^\".]*|\\1%s|' \"%s\"", name, archivo)
	local notify_cmd = string.format("notify-send 'Hyprland Animations' 'Animacion cambiada a %s'", name)
	os.execute(sed_cmd .. " && hyprctl reload && " .. notify_cmd)
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
	local animacion_actual = ObtenerAnimacionActual()
	if handle then
		for line in handle:lines() do
			local name = EliminarExtension(line)
			-- Supongamos que 'nombre' es el de la lista y 'animacion_activa' es la de tu archivo
			local es_actual = (name == animacion_actual) and "Current" or ""
			local nombre = name:gsub("^%l", string.upper):gsub("-", " ")
			table.insert(entries, {
				Text = nombre,
				Value = line,
				Subtext = es_actual,
				Actions = { apply_animation = "lua:ApplyAnimation" },
			})
		end
	end
	return entries
end
