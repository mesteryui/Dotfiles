Name = "main"
NamePretty = "Menu principal"
FixedOrder = true
Icon = ""
Description = "Menu del sistema"
HideFromProviderList = true
SearchName = true

function GetEntries()
 return {
     {
	    Text = "Sobre el sistema",
	    Icon = "󰋽",
	    Actions = {
		["about_system"] = "xdg-terminal-exec --app-id=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'"
	    },
	},
     {
	    Text = "Actualizar",
	    Icon = "",
	    Actions = {
		["update"] = "xdg-terminal-exec --app-id=local.floating -e yay -Syu"
	    },
   },
     {
	 Text = "Atajos de teclado",
	 Icon = "",
	 Actions =  { 
	      show_keybinds = "menubinds.sh" 
	     --show_keybinds = "dms ipc keybinds open hyprland"
	 },
     },
   {
    Text = "Captura",
    Icon = "󰹑",
    SubMenu = "screenshot",
  },
  {
	    Text = "Configuración",
	    Icon = "",
	    SubMenu = "configuration",
	},
  {
      Text = "Apariencia",
      Icon = "",
      SubMenu = "themes",
  },
     {
	 Text = "Juegos",
	 Icon = "󰊗",
	 SubMenu = "games",
     },
     {
	 Text = "Power",
	 Icon = "⏻",
	 Actions = {
		["logout_menu"] = "wlogout"
	    },
     },
 }
end
