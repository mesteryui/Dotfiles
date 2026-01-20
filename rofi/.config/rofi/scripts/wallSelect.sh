#!/bin/bash

# Wallpaper Launcher - Versión Simplificada

# Configuración
WALL_DIR="$HOME/Imágenes/Wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper-launcher"
CACHE_FILE="$CACHE_DIR/wallpapers"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones básicas
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

# Verificar que el directorio existe
if [[ ! -d "$WALL_DIR" ]]; then
    log_error "Directorio no encontrado: $WALL_DIR"
    mkdir -p "$WALL_DIR"
    log_info "Directorio creado. Añade imágenes y ejecuta de nuevo."
    exit 0
fi

# Crear caché si no existe
mkdir -p "$CACHE_DIR"

# Buscar todas las imágenes soportadas
find_images() {
    find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.svg" \) -printf '%f\n' | sort
}

# Generar lista para rofi
generate_list() {
    find_images | while read -r file; do
        filename="${file%.*}"
        filepath="$WALL_DIR/$file"
        printf '%s\x00icon\x1f%s\n' "$filename" "$filepath"
    done
}

# Resolver el nombre completo del archivo desde la selección
resolve_file() {
    local selection="$1"
    find_images | while read -r file; do
        filename="${file%.*}"
        if [[ "$filename" == "$selection" ]]; then
            echo "$file"
            return 0
        fi
    done
}

# Aplicar wallpaper con matugen
apply_wallpaper() {
    local file="$1"
    local path="$WALL_DIR/$file"
    
    if [[ ! -f "$path" ]]; then
        log_error "Archivo no encontrado: $path"
        return 1
    fi
    
    log_info "Aplicando wallpaper..."
    if awww img "$path" --transition-type center >/dev/null 2>&1; then
      log_success "Fondo de pantalla aplicado"
    else
      log_error "Error al aplicar el wallpaper"
    fi

    if matugen image "$path" >/dev/null 2>&1; then
        log_success "Colores aplicados: $file"
    else
        log_error "Error al aplicar colores"
        return 1
    fi
}

# Verificar que matugen está instalado
if ! command -v matugen >/dev/null 2>&1; then
    log_error "matugen no está instalado"
    exit 1
fi

# Verificar que rofi está instalado
if ! command -v rofi >/dev/null 2>&1; then
    log_error "rofi no está instalado"
    exit 1
fi

# Mostrar selector
log_info "Abriendo selector..."
selection=$(generate_list | rofi -dmenu -p "Wallpaper" -theme '~/.config/rofi/layouts/wallConfig.rasi')

# Si se canceló, salir
if [[ -z "$selection" ]]; then
    log_info "Operación cancelada"
    exit 0
fi

log_info "Selección: $selection"

# Resolver el archivo completo
actual_file=$(resolve_file "$selection")

if [[ -z "$actual_file" ]]; then
    log_error "No se pudo encontrar el archivo para: $selection"
    exit 1
fi

# Aplicar wallpaper
apply_wallpaper "$actual_file"
