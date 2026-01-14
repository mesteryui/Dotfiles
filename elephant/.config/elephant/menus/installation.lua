Name = "installation"
NamePretty = "Instalacion"
HideFromProviderList = false
Action = "xdg-terminal-exec --app-id=local.floating -e %VALUE%"
function GetEntries()
    return {
	{
	    Text = "Instalar Paquete",
	    Value = "application-installer",
	},
    }
end
