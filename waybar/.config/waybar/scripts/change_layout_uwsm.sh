#!/usr/bin/env bash

# -----------------------------
# Configuración de directorios
# -----------------------------
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprsphere"
LAYOUT_DIR="$HOME/.config/waybar/layouts"
DEFAULT="default"
CURRENT="$CACHE_DIR/waybar-layout.txt"
ICON_PATH="$HOME/.dotfiles/logo-hyprsphere-min.png"

# Crear directorio de cache si no existe
mkdir -p "$CACHE_DIR"

# Función para mostrar errores con notificación
show_error() {
    local message="$1"
    echo "Error: $message" >&2
    notify-send -t 5000 "HyprSphere - Error" "$message" --icon="dialog-error" 2>/dev/null
    exit 1
}

# Verificar que el directorio de layouts existe
[[ -d "$LAYOUT_DIR" ]] || show_error "El directorio de layouts no existe: $LAYOUT_DIR"

# Crear archivo de layout actual si no existe
[[ -f "$CURRENT" ]] || echo "$DEFAULT" > "$CURRENT"

# Obtener lista de layouts disponibles
layout_list=$(find "$LAYOUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
[[ -n "$layout_list" ]] || show_error "No se encontraron layouts en $LAYOUT_DIR"

# Layout actual
current_layout=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")

# -----------------------------
# Selección de layout con Rofi
# -----------------------------
#selected_layout=$(echo "$layout_list" | rofi -dmenu \
#    -p "Layout actual: $current_layout" \
#    -theme "~/.config/rofi/hyprsphere-selector-layout.rasi" \
#    -no-custom)
selected_layout=$(echo "$layout_list" | walker --dmenu -p "Layout Actual: $current_layout")

# Si se seleccionó un layout válido
if [[ -n "$selected_layout" ]]; then
    [[ -d "$LAYOUT_DIR/$selected_layout" ]] || show_error "El layout seleccionado no existe: $selected_layout"

    # Guardar selección
    echo "$selected_layout" > "$CURRENT"

    # Notificación del cambio
    local_icon="${ICON_PATH:-preferences-desktop}"
    notify-send --app-name="HyprSphere" -t 3000 "HyprSphere" \
        "Layout cambiado: $current_layout → $selected_layout" \
        --icon="$local_icon"

    # -----------------------------
    # Reiniciar Waybar
    # -----------------------------
    if systemctl --user status waybar.service >/dev/null 2>&1; then
        systemctl --user restart waybar.service || show_error "No se pudo reiniciar waybar.service"
    else
	systemctl --user start waybar.service
        show_error "waybar.service no está habilitado en systemd --user"
    fi

else
    echo "Selección cancelada"
    exit 0
fi
