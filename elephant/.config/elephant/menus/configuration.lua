Name = "configuration"
NamePretty = "Configuración"
Icon = ""
Parent = "system"
SearchName = true

function GetEntries()
    return {
	{
	    Text = "Cambiar atajos teclado",
	    Icon = "",
	    Actions = { 
		["cambiar_atajos_teclado"] = "ghostty -e nano $XDG_CONFIG_HOME/hypr/configs/keybinds.conf" },
	},
	{
	    Text = "Permisos del compositor",
	    Icon = "",
	    Actions = { 
		["permisos_del_compositor"] = "ghostty -e nano $XDG_CONFIG_HOME/hypr/configs/permissions.conf" },
	},
	{
	    Text = "Configuracion del monitor",
	    Icon = "󰍹",
	    Actions = { 
		["configuracion_del_monitor"] = "ghostty -e nano $XDG_CONFIG_HOME/hypr/configs/monitors.conf" },
	},
	{
	    Text = "Cambiar DNS",
	    Icon = "󰇖",
	    Actions = { 
		["cambiar_dns"] = "ghostty -e sudo nano /etc/systemd/resolved.conf" },
	},
	{
	    Text = "Power profile",
	    SubMenu = "power-profiles",
	    Icon = "󰚥",
	},
    }
end
