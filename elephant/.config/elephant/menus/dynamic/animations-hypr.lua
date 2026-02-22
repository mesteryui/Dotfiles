Name = "hyprland-animations"
NamePretty = "Hyprland Animations"
Icon = ""
Description = "Menu de animacion"
FixedOrder = true
function ObtenerAnimacionActual()
	-- Usamos la función de ruta para ser consistentes
	local archivo_config = ObtenerHyprAnimsLayoutDir() .. "../animation.conf"

	-- Buscamos la línea 'source =', extraemos lo que hay tras la última / y limpiamos espacios
	local comando = "grep 'source =' " .. archivo_config .. " | sed 's|.*/||' | tr -d '[:space:]'"

	local handle = io.popen(comando)
	if handle then
		local resultado = handle:read("*a")
		handle:close()

		if resultado and resultado ~= "" then
			-- Solo eliminamos la extensión aquí para comparar limpio
			return EliminarExtension(resultado)
		end
	end
	return ""
end
function ApplyAnimation(val)
	local archivo = ObtenerHyprAnimsLayoutDir() .. "../animation.conf"
	local comando = string.format("sed -i 's|\\(source = .*/\\).*|\\1%s|' %s && hyprctl reload", val, archivo)
	os.execute(comando)
	os.execute("notify-send 'Hyprland Animations' 'Animacion cambiada a " .. val .. "'")
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
