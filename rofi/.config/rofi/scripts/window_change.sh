#!/bin/bash

# Script para lanzar rofi window switcher con tema personalizado
# Guarda este archivo como ~/.local/bin/rofi-windows y hazlo ejecutable

# Configuración
THEME="$HOME/.config/rofi/window_switcher.rasi"
ICON_SIZE=64

# Verificar si el tema existe
if [ ! -f "$THEME" ]; then
    echo "Error: No se encontró el tema en $THEME"
    echo "Asegúrate de haber guardado el archivo window-switcher.rasi en ~/.config/rofi/"
    exit 1
fi

# Lanzar rofi en modo window con el tema personalizado
rofi -show window \
     -theme "$THEME" \
     -show-icons \
     -icon-theme "Papirus" \
     -cycle true \
     -eh 2 \
     -auto-select false \
     -parse-hosts false \
     -parse-known-hosts false \
     -combi-modi "window" \
     -matching "fuzzy" \
     -sort true \
     -sorting-method "fzf" \
     -normalize-match true
