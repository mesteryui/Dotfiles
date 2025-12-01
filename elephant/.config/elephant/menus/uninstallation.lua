Name = "uninstallation"
NamePretty = "Desinstalacion"

function GetEntries()
    return {
	{
	    Text = "Desinstalar paquete",
	    Actions = { uninstall = "xdg-terminal-exec --app-id=local.floating -e application-uninstaller" }
	},
    }
end
