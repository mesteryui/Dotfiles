#!/bin/bash

THEME_DIR="$HOME/.config/rofi/layouts/applications_menu/"
CURRENT="$THEME_DIR/current-theme.txt"
DEFAULT="default.rasi"

# Crear archivo si no existe
[ ! -f "$CURRENT" ] && echo "$DEFAULT" > "$CURRENT"

CURRENT_THEME=$(cat "$CURRENT")

# Obtener todos los temas disponibles
THEMES=()
for file in "$THEME_DIR"/*.rasi; do
    THEMES+=("$(basename "$file" .rasi)")
done

# Crear lista para rofi con indicador del actual
THEMES_DISPLAY=()
for theme in "${THEMES[@]}"; do
    if [ "$theme" == "${CURRENT_THEME%.*}" ]; then
        THEMES_DISPLAY+=("| $theme")
    else
        THEMES_DISPLAY+=("$theme")
    fi
done

# Mostrar selector con Rofi
SELECTED=$(printf '%s\n' "${THEMES_DISPLAY[@]}" | rofi -dmenu -p "Layout del menu:")

# Si se seleccionó uno, guardarlo
if [[ -n "$SELECTED" ]]; then
    SELECTED="${SELECTED#* }"
    echo "$SELECTED.rasi" > "$CURRENT"
    notify-send -t 3000 "Menu de sistema" "Cambiando layout a $SELECTED"
fi

