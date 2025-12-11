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
	    Text = "About",
	    Icon = "",
	    Actions = {
		["about_system"] = "ghostty --class=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'"
	    },
	},
     {
	    Text = "Update",
	    Icon = "",
	    Actions = {
		["update"] = "ghostty --class=local.floating -e yay -Syu"
	    },
   },
     {
	 Text = "Atajos de teclado",
	 Icon = "",
	 Actions =  { show_keybinds = "menubinds.sh" },
     },
   {
    Text = "Captura",
    Icon = "󰹑",
    SubMenu = "screenshot",
  },
  {
      Text = "Configuraciones",
      Icon = "",
      SubMenu = "configs",
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
	 SubMenu = "power-menu",
     },
 }
end
