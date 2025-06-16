#!/bin/bash

THEME_DIR="$HOME/.config/rofi/layouts/applications_menu"
CURRENT="$THEME_DIR/current-theme.txt"
DEFAULT="default_conf.rasi"

# Leer el tema actual o usar el default si no existe
THEME_FILE=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")

# Ejecutar Rofi con el tema actual
rofi -show drun -theme "$THEME_DIR/$THEME_FILE" -matching fuzzy
