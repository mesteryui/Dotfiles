#!/bin/bash

THEME_DIR="$HOME/.config/rofi/layouts/applications_menu/"
CURRENT="$THEME_DIR/current-theme.txt"
DEFAULT="default_conf.rasi"

# Crear archivo si no existe
[ ! -f "$CURRENT" ] && echo "$DEFAULT" > "$CURRENT"

# Obtener todos los temas disponibles
THEMES=$(ls "$THEME_DIR"/*.rasi | xargs -n1 basename)

# Mostrar selector con Rofi
SELECTED=$(echo "$THEMES" | rofi -dmenu -p "Layout Actual: $(cat $CURRENT)" -theme "~/.config/rofi/hyprsphere-selector-layout.rasi")

# Si se seleccionó uno, guardarlo
if [[ -n "$SELECTED" ]]; then
    echo "$SELECTED" > "$CURRENT"
    notify-send -t 3000 "HyprSphere" "Cambiando layout" --icon="$HOME/.dotfiles/logo-hyprsphere-min.png"
fi
