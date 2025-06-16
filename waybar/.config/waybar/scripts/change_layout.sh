#!/bin/bash

# Configuración de directorios y archivos
LAYOUT_DIR="$HOME/.config/waybar/layouts/"
DEFAULT="default"
CURRENT="$LAYOUT_DIR/current-layout.txt"
DEFAULT_JSONC="$DEFAULT/config-hypr.jsonc"
DEFAULT_CSS="$DEFAULT/style-hypr.css"
ICON_PATH="$HOME/.dotfiles/logo-hyprsphere-min.png"

# Función para mostrar errores
show_error() {
    local message="$1"
    echo "Error: $message" >&2
    notify-send -t 5000 "HyprSphere - Error" "$message" --icon="dialog-error" 2>/dev/null
    exit 1
}

# Verificar que el directorio de layouts existe
if [[ ! -d "$LAYOUT_DIR" ]]; then
    show_error "El directorio de layouts no existe: $LAYOUT_DIR"
fi

# Crear archivo de layout actual si no existe
if [[ ! -f "$CURRENT" ]]; then
    echo "$DEFAULT" > "$CURRENT" || show_error "No se pudo crear el archivo de layout actual"
fi

# Obtener lista de layouts disponibles con saltos de línea
layout_list=$(find "$LAYOUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

# Verificar que hay layouts disponibles
if [[ -z "$layout_list" ]]; then
    show_error "No se encontraron layouts en $LAYOUT_DIR"
fi

# Mostrar el layout actual en el prompt
current_layout=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")

# Usar rofi para seleccionar layout con prompt personalizado
selected_layout=$(echo "$layout_list" | rofi -dmenu \
    -p "Layout actual: $current_layout │ Seleccionar:" \
    -theme-str 'window {width: 400px;}' \
    -theme-str 'listview {lines: 8;}' \
    -no-custom)

# Procesar selección
if [[ -n "$selected_layout" ]]; then
    # Verificar que el layout seleccionado existe
    if [[ ! -d "$LAYOUT_DIR/$selected_layout" ]]; then
        show_error "El layout seleccionado no existe: $selected_layout"
    fi
    
    # Guardar el layout seleccionado
    echo "$selected_layout" > "$CURRENT" || show_error "No se pudo guardar el layout seleccionado"
    
    # Mostrar notificación con información del cambio
    if [[ -f "$ICON_PATH" ]]; then
        notify-send -t 3000 "HyprSphere" \
            "Layout cambiado: $current_layout → $selected_layout" \
            --icon="$ICON_PATH"
    else
        notify-send -t 3000 "HyprSphere" \
            "Layout cambiado: $current_layout → $selected_layout" \
            --icon="preferences-desktop"
    fi
    
    # Ejecutar launch.sh (usando exec para reemplazar el proceso actual)
    if command -v launch.sh >/dev/null 2>&1; then
        exec launch.sh
    else
        # Buscar launch.sh en el PATH y directorios comunes
        for path in "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin" "$(dirname "$0")"; do
            if [[ -x "$path/launch.sh" ]]; then
                exec "$path/launch.sh"
            fi
        done
        show_error "No se encontró el script launch.sh"
    fi
else
    echo "Selección cancelada"
    exit 0
fi
