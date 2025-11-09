Name = "games"
NamePretty = "Juegos y otras cosas"
Icon = "󰊗"
FixedOrder = true

function GetEntries()
 return {
   {
    Text = "Steam",
    Icon = "󰓓",
    Actions = {
     ["steam"] = "kitty --class=float_kitty -e steam-setup.sh"
    },
  },
 }
end
