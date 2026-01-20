#!/usr/bin/env bash
profiles=$(powerprofilesctl list | awk '/:/ && !/CpuDriver|PlatformDriver|Degraded/ {
    gsub(/:/, ""); # Quitamos los dos puntos de toda la línea primero
    
    if ($1 == "*") {
        printf "|%s\n", $2; # El activo: imprimimos la barra y el segundo campo
    } else {
        printf "%s\n", $1; # Los inactivos: imprimimos espacios y el primer campo
    }
}')
profile=$(echo -e "$profiles" | rofi -dmenu -theme "~/.config/rofi/layouts/system-menu.rasi")

if [ -n "$profile" ]; then
   profile_clean="${profile#* }"
   powerprofilesctl set "$profile_clean"
   notify-send "Cambio de perfil de energia" "Cambiando perfil de energia a $profile"
fi
