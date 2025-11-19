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
    Text = "About",
    Icon = "",
    Actions = {
	["about_system"] = "ghostty --class=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'"
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
      Text = "Temas",
      Icon = "",
      SubMenu = "themes",
  },
  {
    Text = "Keybindings",
    Icon = "",
    Actions = {
      ["keybindings"] = "menubinds.sh"
    },
  },
  {
    Text = "Setup",
    Icon = "󰉉",
    SubMenu = "setup",
  },
  {
      Text = "Packages",
      Icon = "󰏖",
      SubMenu = "packages",
  },
  {
    Text = "Juegos y otras cosas",
    Icon = "󰊗",
    SubMenu = "games",
  },
 }
end
