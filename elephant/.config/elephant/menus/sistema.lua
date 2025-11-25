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
      Text = "Packages",
      Icon = "󰏖",
      SubMenu = "packages",
  },
  {
    Text = "Setup",
    Icon = "󰉉",
    SubMenu = "setup",
  },
  {
    Text = "Configuración",
    Icon = "",
    SubMenu = "configuration",
  },
  {
    Text = "About",
    Icon = "",
    Actions = {
	["about_system"] = "ghostty --class=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'"
    },
  },
    }
end
