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
	    Text = "Update",
	    Icon = "",
	    Actions = {
		["update"] = "ghostty --class=local.floating -e paru -Syu"
	    },
	},
   {
    Text = "Captura",
    Icon = "󰹑",
    SubMenu = "screenshot",
  },
  {
      Text = "Sistema",
      Icon = "",
      SubMenu = "system",
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
 }
end
