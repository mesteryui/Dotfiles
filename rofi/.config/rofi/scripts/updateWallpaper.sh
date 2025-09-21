#!/bin/bash

# Script simple para actualizar wallpaper en temas Rofi con imageBox
# Uso: ./update-rofi-wallpaper.sh /ruta/al/nuevo/wallpaper.jpg

THEME_DIR="$HOME/.config/rofi/layouts/applications_menu/"

# 1. Verificar si se proporcionó un argumento y si es un archivo válido
if [[ -z "$1" || ! -f "$1" ]]; then
    echo "Error: Por favor, proporciona la ruta del wallpaper como argumento."
    echo "Uso: $0 /ruta/al/nuevo/wallpaper.jpg"
    exit 1
fi

WALLPAPER=$(readlink -f "$1")

echo "Wallpaper a usar: $WALLPAPER"

# 2. Buscar y actualizar archivos .rasi que contengan imageBox
find "$THEME_DIR" -name "*.rasi" -type f | while read -r theme_file; do
    if grep -q "imageBox" "$theme_file"; then
        echo "Actualizando: $(basename "$theme_file")"

        # Reemplazar la línea background-image en imageBox
        # Usamos '|' como separador en sed para evitar conflictos con las '/' en la ruta
        sed -i "/imageBox/,/}/ s|background-image: url(.*);|background-image: url(\"$WALLPAPER\", height);|" "$theme_file"
    fi
done

echo "Wallpapers actualizados en temas con imageBox."
