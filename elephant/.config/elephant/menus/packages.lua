Name = "packages"
NamePretty = "Menu Paquetes"
FixedOrder = true


function GetEntries()
    return {
	{
	    Text = "Instalacion",
	    Icon = "",
	    SubMenu = "installation",
	},
	{
	    Text = "Desinstalacion",
	    Icon = "",
	    SubMenu = "uninstallation",
	},
    }
end
