Name = "power-profiles"
NamePretty = "Power profiles"
HideFromProviderlist = true
Cache = false
Action = "powerprofilesctl set %VALUE%; notify-send 'Power Profile' 'Set to %VALUE%'"
Icon = "󰁹"
Description = "Menu perfiles de energia"

function RealizarInsercion(profile_name, tabla, icon, line)
	if profile_name then
		local is_current = line:match("^%*")
		table.insert(tabla, {
			Text = profile_name:gsub("^%l", string.upper):gsub("-", " "),
			Value = profile_name,
			Subtext = is_current and "Current" or "",
			Icon = icon or "",
		})
	end
end
function GetEntries()
	local entries = {}
	local handle = io.popen("powerprofilesctl list")
	local icons = { "", " ", "󰌪" }
	if not handle then
		return entries
	end
	for line in handle:lines() do
		local profile_name = line:match("^[* ] ([%a-]+):")
		local position = #entries + 1
		local icon = icons[position]
		RealizarInsercion(profile_name, entries, icon, line)
	end

	handle:close()

	if #entries == 0 then
		table.insert(entries, {
			Text = "No power profiles found",
			Value = "",
		})
	end

	return entries
end
