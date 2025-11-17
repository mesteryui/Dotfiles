Name = "themes"
NamePretty = "Temas"
HideFromProviderList = true
SearchName = true
Icon = ""
Parent = "main"
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
    }
end
