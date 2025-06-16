#!/bin/bash 

LAYOUT_DIR="$HOME/.config/waybar/layouts"
CURRENT="$LAYOUT_DIR/current-layout.txt"
DEFAULT="default"

# Lee el layout actual o usa "default"
layout=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")

# Ruta completa al layout
layout_path="$LAYOUT_DIR/$layout"

# Comprueba si existen archivos .jsonc y .css
json_file=$(find "$layout_path" -maxdepth 1 -type f -name "*.jsonc" -exec basename {} \; | head -n 1)
css_file=$(find "$layout_path" -maxdepth 1 -type f -name "*.css" -exec basename {} \; | head -n 1)

# Validaciones opcionales (por si quieres ver si alguno falta)
if [[ -z "$json_file" ]]; then
  echo "❌ No se encontró archivo .jsonc en $layout_path"
  exit 1
fi

if [[ -z "$css_file" ]]; then
  echo "❌ No se encontró archivo .css en $layout_path"
  exit 1
fi

killall -9 waybar
# Ejecutar Waybar con los archivos encontrados
waybar -s "$layout_path/$css_file" -c "$layout_path/$json_file"
