Name = "wallpapers"
NamePretty = "Wallpapers"
HideFromProviderlist = true
Cache = false
GlobalSearch = false

function ApplyWallpaper(wallpaper)
	local wallpapers_dir = os.getenv("HOME") .. "/Bildoj/Wallpapers"
	os.execute('awww img "' .. wallpaper .. '" --transition-type center')
	os.execute("cp '" .. wallpaper .. "' " .. wallpapers_dir .. "/.current_wallpaper")
	os.execute("matugen image '" .. wallpaper .. "' --source-color-index 0")
end

function GetEntries()
	local entries = {}
	local wallpapers_dir = os.getenv("HOME") .. "/Bildoj/Wallpapers"
	local find_cmd = "find '"
		.. wallpapers_dir
		.. '\' -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.svg" \\) 2>/dev/null'

	local wallpaper_see = io.popen(find_cmd)
	if wallpaper_see then
		for line in wallpaper_see:lines() do
			local filename = line:match("([^/]+)$")
			if filename then
				table.insert(entries, {
					Text = filename:gsub("%.[^.]+$", ""),
					Value = line,
					Preview = line,
					PreviewType = "file",
					Actions = { apply = "lua:ApplyWallpaper" },
				})
			end
		end
		wallpaper_see:close()
	end
	return entries
end
