#!/bin/bash
option=$(echo -e " About\n Actualizar\n Keybinds\n Apariencia\n Configuracion" | rofi -dmenu -theme '~/.config/rofi/layouts/system-menu.rasi')

case ${option#* } in
  "About")
     xdg-terminal-exec --app-id=local.floating -e $SHELL -c 'fastfetch;read -n 1;exit'
    ;;
  "Keybinds")
    menubinds.sh
    ;;
  "Configuracion")
    ~/.config/rofi/scripts/system_submenus/configuration_menu.sh
    ;;
  "Actualizar")
    xdg-terminal-exec --app-id=local.floating -e yay -Syu
    ;;
  "Apariencia")
    ~/.config/rofi/scripts/system_submenus/appearence_menu.sh
    ;;
esac
