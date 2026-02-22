Name = "themes"
NamePretty = "Apariencia"
HideFromProviderList = true
SearchName = true
Icon = ""
Parent = "main"
FixedOrder = true
function GetEntries()
	return {
		{
			Text = "Fastfetch",
			Icon = "",
			SubMenu = "fastfetch",
		},
		{
			Text = "Waybar",
			Icon = "",
			SubMenu = "waybar-layout-selector",
		},
		{
			Text = "Wallpapers",
			Icon = "",
			SubMenu = "wallpapers",
		},
		{
			Text = "Animaciones",
			Icon = "",
			SubMenu = "hyprland-animations",
		},
	}
end
