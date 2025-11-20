Name = "packages"
NamePretty = "Menu Paquetes"
FixedOrder = true

function GetEntries()
    return {
	{
	    Text = "Instalar Paquete",
	    Actions = {
		["install_package"] = "ghostty --class=local.floating -e application-installer"
	    },
	},
    }
end
