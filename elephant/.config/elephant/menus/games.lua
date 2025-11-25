Name = "games"
NamePretty = "Juegos"
Icon = "󰊗"
FixedOrder = true

function GetEntries()
 return {
   {
    Text = "Steam",
    Icon = "󰓓",
    Actions = {
     ["steam"] = "kitty --class=float_kitty -e steam-setup"
    },
  },
 }
end
