#/usr/bin/env bash

opcion=$(echo -e " Waybar\n Fastfetch\n󰸉 Wallpapers" | rofi -dmenu -theme ~/.config/rofi/layouts/system-menu.rasi)

case ${opcion#* } in
  "Waybar")
    ~/.config/rofi/scripts/waybar-selector.sh
    ;;
  "Wallpapers")
    ~/.config/rofi/scripts/wallSelect.sh
    ;;
  "Fastfetch")
    ~/.config/rofi/scripts/system_submenus/fastfetch-menu.sh
    ;;
esac
