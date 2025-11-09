Name = "system"
NamePretty = "System"
Icon = ""
HideFromProviderlist = true
Parent = "main"
Cache = true
SearchName = true

function GetEntries()
    return {
	{
	    Text = "Power profile",
	    SubMenu = "power-profiles",
	    Icon = "󰚥",
	},
	{
            Text = "Cambiar atajos teclado",
            Icon = "",
            Action = "kitty --class=float_kitty -e nano $XDG_CONFIG_HOME/hypr/configs/keybinds.conf",
        },
        {
            Text = "Permisos del compositor",
            Icon = "",
            Action = "kitty --class=float_kitty -e nano $XDG_CONFIG_HOME/hypr/configs/permissions.conf",
        },
        {
            Text = "Configuracion del monitor",
            Icon = "󰍹",
            Action = "kitty --class=float_kitty -e nano $XDG_CONFIG_HOME/hypr/configs/monitors.conf",
        },
        {
            Text = "Cambiar DNS",
            Icon = "󰇖",
            Action = "kitty --class=float_kitty -e sudo nano /etc/systemd/resolved.conf",
        },
    }
end
