#!/usr/bin/env bash

selected=$(echo -e "󰇖 Cambiar DNS\n Permisos del compositor\n󰍹 Configuracion del monitor\n󰚥 Perfiles de energia" | rofi -dmenu -theme "~/.config/rofi/layouts/system-menu.rasi")

case "${selected#* }" in
  "Cambiar DNS")
     xdg-terminal-exec -e sudo nano /etc/systemd/resolved.conf
    ;;
  "Permisos del compositor")
    xdg-terminal-exec -e nano $XDG_CONFIG_HOME/hypr/configs/permissions.conf
    ;;
  "Cambiar atajos de teclado")
  ghostty -e nano $XDG_CONFIG_HOME/hypr/configs/keybinds.conf
  ;;
"Configuracion del monitor")
 xdg-terminal-exec -e nano $XDG_CONFIG_HOME/hypr/configs/monitors.conf
  ;;
"Perfiles de energia")
  $XDG_CONFIG_HOME/rofi/scripts/system_submenus/power-profiles.sh
  ;;
esac
