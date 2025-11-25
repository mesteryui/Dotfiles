Name = "packages"
NamePretty = "Menu Paquetes"
FixedOrder = true

function GetEntries()
    return {
	{
	    Text = "Instalar Paquete",
	    Icon = "",
	    Actions = {
		["install_package"] = "ghostty --class=local.floating -e application-installer"
	    },
	},
	{
	    Text = "Desinstalar Paquete",
	    Icon = "",
	    Actions = {
		["install_package"] = "ghostty --class=local.floating -e application-uninstaller"
	    },
	},
    }
end
