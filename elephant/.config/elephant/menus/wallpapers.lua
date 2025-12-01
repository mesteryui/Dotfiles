Name = "wallpapers"
NamePretty = "Wallpapers"
HideFromProviderlist = true
Cache = false
GlobalSearch = false

function ApplyWallpaper(wallpaper)
    os.execute("swww img "..wallpaper .. " --transition-type center")
    os.execute("matugen image "..wallpaper)
end

function GetEntries()
    local entries = {}
    local wallpapers_dir = os.getenv("HOME") .. "/Imágenes/Wallpapers"
    local wallpaper_see = io.popen("find '" .. wallpapers_dir .. "' -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) | sort")
    if wallpaper_see then
	for line in wallpaper_see:lines() do
	    local filename = line:match("([^/]+)$")
	    if filename then
		table.insert(entries,{
		    Text = filename:gsub("%.[^.]+$", ""),
		    Value = line,
		    Preview = line,
		    PreviewType = "file",
		    Actions = { apply = "lua:ApplyWallpaper"}
		})
	    end
	end
	wallpaper_see:close()
    end
    return entries
end
