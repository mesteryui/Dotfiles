Name = "configs"
NamePretty = "Configuraciones"
Icon = ""
HideFromProviderlist = true
Parent = "main"
Cache = true
SearchName = true

function GetEntries()
    return {
	
	{
	    Text = "Packages",
	    Icon = "󰏖",
	    SubMenu = "packages",
	},
	{
	    Text = "Setup",
	    Icon = "󰉉",
	    SubMenu = "setup",
	},
	{
	    Text = "Configuración",
	    Icon = "",
	    SubMenu = "configuration",
	},
    }
end
