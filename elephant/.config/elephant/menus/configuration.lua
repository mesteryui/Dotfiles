Name = "configuration"
NamePretty = "Configuración"
Icon = ""
Parent = "main"
SearchName = true

function GetEntries()
	return {
		{
			Text = "Cambiar atajos teclado",
			Icon = "",
			Actions = {
				["cambiar_atajos_teclado"] = "emacsclient -c -a 'emacs' ~/.config/hypr/configs/keybinds/",
			},
		},
		{
			Text = "Permisos del compositor",
			Icon = "",
			Actions = {
				["permisos_del_compositor"] = "emacsclient -c -a 'emacs' $XDG_CONFIG_HOME/hypr/configs/permissions.conf",
			},
		},
		{
			Text = "Configuracion del monitor",
			Icon = "󰍹",
			Actions = {
				["configuracion_del_monitor"] = "emacsclient -c -a 'emacs' $XDG_CONFIG_HOME/hypr/configs/monitors.conf",
			},
		},
		{
			Text = "Daemon de notificaciones",
			Icon = "",
			Actions = { ["configuracion_notificaciones"] = "emacsclient -c -a 'emacs' ~/.config/swaync/config.json" },
		},
		{
			Text = "Configuracion de Waybar",
			Icon = "",
			Actions = { ["configuracion_waybar"] = "emacsclient -c -a 'emacs' ~/.config/waybar/config.jsonc" },
		},
		{
			Text = "Cambiar DNS",
			Icon = "󰇖",
			Actions = {
				["cambiar_dns"] = "emacsclient -c -a 'emacs' '/sudo::/etc/systemd/resolved.conf'",
			},
		},
		{
			Text = "Power profile",
			SubMenu = "power-profiles",
			Icon = "󰚥",
		},
	}
end
