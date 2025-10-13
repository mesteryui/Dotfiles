#!/bin/bash

THEME_DIR="$HOME/.config/rofi/layouts/applications_menu"
CURRENT="$THEME_DIR/current-theme.txt"
DEFAULT="default.rasi"

# Leer el tema actual o usar el default si no existe
THEME_FILE=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")

# Ejecutar Rofi con el tema actual
rofi -show drun \
     -theme "$THEME_DIR/$THEME_FILE" \
     -matching fuzzy \
     -case-insensitive \
     -sort true \
     -sorting-method fzf \
     -levenshtein-sort true \
     -normalize true \
     -show-icons \
     -drun-match-fields name,generic,exec \
     -threads 4 \
     -limit 25 \
     -run-command "uwsm app -- {cmd}"

