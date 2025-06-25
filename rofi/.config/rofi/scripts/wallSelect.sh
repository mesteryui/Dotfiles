#!/bin/bash
#  ██╗    ██╗ █████╗ ██╗     ██╗     ██████╗  █████╗ ██████╗ ███████╗██████╗
#  ██║    ██║██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
#  ██║ █╗ ██║███████║██║     ██║     ██████╔╝███████║██████╔╝█████╗  ██████╔╝
#  ██║███╗██║██╔══██║██║     ██║     ██╔═══╝ ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗
#  ╚███╔███╔╝██║  ██║███████╗███████╗██║     ██║  ██║██║     ███████╗██║  ██║
#   ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
#
#  ██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗███████╗██████╗
#  ██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║██╔════╝██╔══██╗
#  ██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║█████╗  ██████╔╝
#  ██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║██╔══╝  ██╔══██╗
#  ███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║███████╗██║  ██║
#  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
#
# Ultra Optimized Wallpaper Launcher - Versión Corregida
# Solucionados problemas de resolución de archivos

set -euo pipefail  # Strict error handling

# Configuration - Centralized and optimized
readonly WALL_DIR="${HOME}/Imágenes/Wallpapers"
readonly ROFI_CONFIG="${HOME}/.config/rofi/wallConfig.rasi"
readonly CACHE_DIR="${HOME}/.cache/wallpaper-launcher"
readonly CACHE_FILE="${CACHE_DIR}/wallpaper_cache"
readonly TEMP_PREFIX="/tmp/wallpaper_$$"
readonly LOGO_ICON="${HOME}/.dotfiles/logo-hyprsphere-min.png"

# Optimized supported formats (most common first)
readonly -a SUPPORTED_FORMATS=("png" "jpg" "jpeg" "webp" "gif" "bmp" "tiff")

# Colors - Optimized constants
readonly RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[1;33m' 
readonly BLUE=$'\033[0;34m' NC=$'\033[0m'

# Ultra-fast logging with built-in formatting
log() {
    case "$1" in
        E) printf "${RED}[ERROR]${NC} %s\n" "$2" >&2 ;;
        S) printf "${GREEN}[SUCCESS]${NC} %s\n" "$2" >&2 ;;
        I) printf "${BLUE}[INFO]${NC} %s\n" "$2" >&2 ;;
        W) printf "${YELLOW}[WARNING]${NC} %s\n" "$2" >&2 ;;
    esac
}

# Fast notification system
notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -t "$1" "HyprSphere" "$2" --icon="${LOGO_ICON:-}" ${3:+--urgency="$3"} 2>/dev/null &
    fi
}

# Ultra-optimized directory check with auto-creation
setup_directories() {
    if [[ ! -d "$WALL_DIR" ]]; then
        log W "Directorio no encontrado: $WALL_DIR"
        if mkdir -p "$WALL_DIR"; then
            log S "Directorio creado: $WALL_DIR"
            log I "Añade imágenes y ejecuta nuevamente"
            exit 0
        else
            log E "Error creando directorio: $WALL_DIR"
            exit 1
        fi
    fi
    
    # Setup cache directory
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
}

# Lightning-fast image discovery with caching
discover_images() {
    local -a find_args=()
    local fmt
    
    # Build optimized find expression
    for fmt in "${SUPPORTED_FORMATS[@]}"; do
        if [[ ${#find_args[@]} -gt 0 ]]; then
            find_args+=(-o)
        fi
        find_args+=(-iname "*.${fmt}")
    done
    
    # Use find with optimized parameters
    find "$WALL_DIR" -maxdepth 1 -type f \( "${find_args[@]}" \) \
        -printf '%f\n' 2>/dev/null | sort -V || true
}

# Optimized cache system
use_cache() {
    local wall_dir_mtime cache_mtime
    
    [[ -f "$CACHE_FILE" ]] || return 1
    
    # Compare modification times
    wall_dir_mtime=$(stat -c %Y "$WALL_DIR" 2>/dev/null || echo 0)
    cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    
    (( cache_mtime > wall_dir_mtime ))
}

# Ultra-fast wallpaper list generation
generate_wallpaper_list() {
    local temp_file="$1"
    local -a images
    
    # Try cache first
    if use_cache && [[ -s "$CACHE_FILE" ]]; then
        log I "Usando caché de wallpapers"
        cp "$CACHE_FILE" "$temp_file"
        return 0
    fi
    
    log I "Generando lista de wallpapers..."
    
    # Discover images efficiently
    readarray -t images < <(discover_images)
    
    if (( ${#images[@]} == 0 )); then
        log E "No se encontraron imágenes en: $WALL_DIR"
        log I "Formatos soportados: ${SUPPORTED_FORMATS[*]}"
        exit 1
    fi
    
    # Generate rofi format - CORREGIDO: Usar nombre completo como clave
    {
        local filename basename_no_ext
        for filename in "${images[@]}"; do
            basename_no_ext="${filename%.*}"
            printf '%s\x00icon\x1f%s/%s\n' "$basename_no_ext" "$WALL_DIR" "$filename"
        done
    } > "$temp_file"
    
    # Update cache
    cp "$temp_file" "$CACHE_FILE" 2>/dev/null || true
    
    log S "Encontradas ${#images[@]} imágenes"
}

# Optimized rofi execution
launch_rofi() {
    local temp_file="$1"
    local rofi_cmd="rofi -dmenu -markup-rows"
    
    # Add theme if available
    if [[ -f "$ROFI_CONFIG" ]]; then
        rofi_cmd+=" -theme '$ROFI_CONFIG'"
    fi
    
    # Log to stderr para no interferir con la salida de rofi
    log I "Abriendo selector..." >&2
    
    # Launch rofi efficiently - redirigir stderr para evitar contaminación
    eval "$rofi_cmd" < "$temp_file" 2>/dev/null
}

# Ultra-fast filename resolution - COMPLETAMENTE REESCRITO
resolve_filename() {
    local selection="$1"
    local filename full_path
    
    log I "Buscando archivo para selección: '$selection'"
    
    # Buscar en el directorio directamente
    while IFS= read -r -d '' full_path; do
        filename=$(basename "$full_path")
        local basename_no_ext="${filename%.*}"
        
        log I "Comparando '$basename_no_ext' con '$selection'"
        
        # Comparación exacta (case-sensitive)
        if [[ "$basename_no_ext" == "$selection" ]]; then
            log S "Coincidencia exacta encontrada: $filename"
            echo "$filename"
            return 0
        fi
    done < <(find "$WALL_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
    
    # Si no se encuentra coincidencia exacta, buscar case-insensitive
    log W "No se encontró coincidencia exacta, buscando case-insensitive..."
    
    while IFS= read -r -d '' full_path; do
        filename=$(basename "$full_path")
        local basename_no_ext="${filename%.*}"
        
        # Comparación case-insensitive
        if [[ "${basename_no_ext,,}" == "${selection,,}" ]]; then
            log S "Coincidencia case-insensitive encontrada: $filename"
            echo "$filename"
            return 0
        fi
    done < <(find "$WALL_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
    
    log E "No se pudo resolver el archivo para: '$selection'"
    return 1
}

# Optimized wallpaper application
apply_wallpaper() {
    local wallpaper_path="$1"
    
    # Immediate feedback
    notify 1000 "⚡ Aplicando wallpaper..."
    log I "Aplicando wallpaper con matugen..."
    
    # Apply with error handling
    if matugen image "$wallpaper_path" >/dev/null 2>&1; then
        log S "Wallpaper aplicado: $(basename "$wallpaper_path")"
        notify 1500 "✓ Wallpaper cambiado exitosamente"
        return 0
    else
        log E "Error aplicando wallpaper con matugen"
        notify 3000 "✗ Error al cambiar wallpaper" critical
        return 1
    fi
}

# Cleanup function
cleanup() {
    rm -f "${TEMP_PREFIX}"* 2>/dev/null || true
}

# Main execution flow - Ultra optimized
main() {
    local temp_file="${TEMP_PREFIX}_list"
    local selection actual_filename wallpaper_path
    
    # Setup cleanup
    trap cleanup EXIT INT TERM
    
    log I "🚀 Iniciando selector de wallpapers (versión corregida)..."
    
    # Debug mode - MEJORADO
    if [[ "${1:-}" == "--debug" ]]; then
        log I "Modo debug - verificando componentes..."
        
        # Test rofi
        if printf "Test 1\nTest 2\nTest 3" | rofi -dmenu -p "Test" >/dev/null 2>&1; then
            log S "Rofi funciona correctamente"
        else
            log E "Rofi no funciona"
            exit 1
        fi
        
        # List wallpapers found
        log I "Wallpapers encontrados:"
        readarray -t debug_images < <(discover_images)
        for img in "${debug_images[@]}"; do
            log I "  - $img"
        done
        
        exit 0
    fi
    
    # Verify matugen availability early
    if ! command -v matugen >/dev/null 2>&1; then
        log E "matugen no está instalado"
        notify 4000 "✗ matugen no está instalado" critical
        exit 1
    fi
    
    # Setup environment
    setup_directories
    
    # Generate wallpaper list (cached when possible)
    generate_wallpaper_list "$temp_file"
    
    # Launch rofi and get selection
    selection=$(launch_rofi "$temp_file" 2>/dev/null)
    local rofi_exit_code=$?
    
    if [[ $rofi_exit_code -ne 0 ]]; then
        case $rofi_exit_code in
            1) log I "Selección cancelada"; exit 0 ;;
            *) log E "Error en rofi (código: $rofi_exit_code)"; exit 1 ;;
        esac
    fi
    
    # Validate selection y limpiar cualquier contaminación
    selection=$(echo "$selection" | tail -n1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    if [[ -z "$selection" ]]; then
        log I "Sin selección"
        exit 0
    fi
    
    log S "Selección: '$selection'"
    
    # Resolve actual filename ultra-fast
    if ! actual_filename=$(resolve_filename "$selection"); then
        log E "Archivo no encontrado para: '$selection'"
        
        # Mostrar archivos disponibles para debug
        log I "Archivos disponibles:"
        readarray -t available_files < <(discover_images)
        for file in "${available_files[@]}"; do
            log I "  - ${file%.*}"
        done
        
        exit 1
    fi
    
    wallpaper_path="$WALL_DIR/$actual_filename"
    
    # Final verification and application
    if [[ ! -f "$wallpaper_path" ]]; then
        log E "Archivo no accesible: $wallpaper_path"
        exit 1
    fi
    
    log I "Archivo resuelto: $wallpaper_path"
    
    # Apply wallpaper
    apply_wallpaper "$wallpaper_path"
}

# Execute with all arguments
main "$@"
