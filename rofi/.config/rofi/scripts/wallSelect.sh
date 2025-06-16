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
# Ultra Optimized Wallpaper Launcher - Maximum Performance Edition
# Enhanced version with ultra-large previews and maximum optimization

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
        S) printf "${GREEN}[SUCCESS]${NC} %s\n" "$2" ;;
        I) printf "${BLUE}[INFO]${NC} %s\n" "$2" ;;
        W) printf "${YELLOW}[WARNING]${NC} %s\n" "$2" ;;
    esac
}

# Fast notification system with better error handling
notify() {
    local duration="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    if command -v notify-send >/dev/null 2>&1; then
        # Use proper icon path or fallback
        local icon_opt=""
        if [[ -f "$LOGO_ICON" ]]; then
            icon_opt="--icon=$LOGO_ICON"
        fi
        
        notify-send --expire-time="$duration" --urgency="$urgency" \
                   $icon_opt "HyprSphere" "$message" 2>/dev/null || true
    fi
}

# Ultra-optimized directory check with auto-creation
setup_directories() {
    [[ -d "$WALL_DIR" ]] || {
        log W "Directorio no encontrado: $WALL_DIR"
        if mkdir -p "$WALL_DIR" 2>/dev/null; then
            log S "Directorio creado: $WALL_DIR"
            log I "Añade imágenes y ejecuta nuevamente"
            exit 0
        else
            log E "Error creando directorio: $WALL_DIR"
            exit 1
        fi
    }
    
    # Setup cache directory
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
}

# Lightning-fast image discovery with caching
discover_images() {
    local -a find_args=()
    local fmt
    
    # Build optimized find expression
    for fmt in "${SUPPORTED_FORMATS[@]}"; do
        find_args+=(-iname "*.${fmt}" -o)
    done
    unset 'find_args[-1]'  # Remove last -o
    
    # Use find with optimized parameters
    find "$WALL_DIR" -maxdepth 1 -type f \( "${find_args[@]}" \) \
        -printf '%f\n' 2>/dev/null | sort -V
}

# Optimized cache system
use_cache() {
    local wall_dir_mtime cache_mtime
    
    [[ -f "$CACHE_FILE" ]] || return 1
    
    # Compare modification times - more robust approach
    if wall_dir_mtime=$(stat -c %Y "$WALL_DIR" 2>/dev/null) && \
       cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null); then
        (( cache_mtime > wall_dir_mtime ))
    else
        return 1
    fi
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
    
    # Generate rofi format in parallel-friendly way
    {
        local filename
        for filename in "${images[@]}"; do
            printf '%s\x00icon\x1f%s/%s\n' "${filename%.*}" "$WALL_DIR" "$filename"
        done
    } > "$temp_file"
    
    # Update cache
    cp "$temp_file" "$CACHE_FILE" 2>/dev/null || true
    
    log S "Encontradas ${#images[@]} imágenes"
}

# Optimized rofi execution with better error handling
launch_rofi() {
    local temp_file="$1"
    local -a rofi_cmd=("rofi" "-dmenu" "-markup-rows")
    
    # Add theme if available
    if [[ -f "$ROFI_CONFIG" ]]; then
        rofi_cmd+=("-theme" "$ROFI_CONFIG")
    fi
    
    # Launch rofi efficiently with proper error handling
    # Redirect stderr to avoid mixing with selection output
    "${rofi_cmd[@]}" < "$temp_file" 2>/dev/null
}

# Ultra-fast filename resolution
resolve_filename() {
    local selection="$1"
    local filename
    
    # Fast direct lookup using globbing - case sensitive first
    for filename in "$WALL_DIR"/"$selection".{png,jpg,jpeg,webp,gif,bmp,tiff,PNG,JPG,JPEG,WEBP,GIF,BMP,TIFF}; do
        if [[ -f "$filename" ]]; then
            basename "$filename"
            return 0
        fi
    done
    
    # Fallback to case-insensitive search if needed
    while IFS= read -r -d '' filename; do
        local basename_no_ext="${filename##*/}"
        basename_no_ext="${basename_no_ext%.*}"
        if [[ "${basename_no_ext,,}" == "${selection,,}" ]]; then
            basename "$filename"
            return 0
        fi
    done < <(find "$WALL_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
    
    return 1
}

# Check if we're in a Hyprland session
is_hyprland_session() {
    [[ "${XDG_CURRENT_DESKTOP:-}" == *"Hyprland"* ]] || \
    [[ "${DESKTOP_SESSION:-}" == *"Hyprland"* ]] || \
    pgrep -x Hyprland >/dev/null 2>&1
}

# Apply wallpaper with multiple methods for maximum compatibility
apply_wallpaper() {
    local wallpaper_path="$1"
    local success=false
    
    # Immediate feedback
    notify 1000 "⚡ Aplicando wallpaper..."
    log I "Aplicando wallpaper: $(basename "$wallpaper_path")"
    
    # Method 1: Try matugen first (preferred method)
    if command -v matugen >/dev/null 2>&1; then
        log I "Usando matugen para aplicar wallpaper..."
        if matugen image "$wallpaper_path" 2>/dev/null; then
            success=true
            log S "Wallpaper aplicado con matugen"
        else
            log W "matugen falló, intentando método alternativo..."
        fi
    else
        log W "matugen no encontrado, usando método alternativo..."
    fi
    
    # Method 2: Hyprland direct method if matugen failed
    if ! $success && is_hyprland_session; then
        if command -v hyprctl >/dev/null 2>&1; then
            log I "Usando hyprctl para aplicar wallpaper..."
            if hyprctl hyprpaper wallpaper ",$wallpaper_path" 2>/dev/null || \
               hyprctl dispatch exec "hyprpaper -c ~/.config/hypr/hyprpaper.conf" 2>/dev/null; then
                success=true
                log S "Wallpaper aplicado con hyprctl"
            fi
        fi
    fi
    
    # Method 3: Try swww as fallback
    if ! $success && command -v swww >/dev/null 2>&1; then
        log I "Usando swww para aplicar wallpaper..."
        if swww img "$wallpaper_path" --transition-type fade --transition-duration 0.5 2>/dev/null; then
            success=true
            log S "Wallpaper aplicado con swww"
        fi
    fi
    
    # Method 4: Try feh as last resort
    if ! $success && command -v feh >/dev/null 2>&1; then
        log I "Usando feh para aplicar wallpaper..."
        if feh --bg-fill "$wallpaper_path" 2>/dev/null; then
            success=true
            log S "Wallpaper aplicado con feh"
        fi
    fi
    
    # Final result
    if $success; then
        log S "Wallpaper cambiado exitosamente: $(basename "$wallpaper_path")"
        notify 2000 "✓ Wallpaper cambiado exitosamente"
        return 0
    else
        log E "Error: No se pudo aplicar el wallpaper con ningún método"
        notify 4000 "✗ Error al cambiar wallpaper" critical
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
    
    log I "🚀 Iniciando selector de wallpapers (modo ultra-optimizado)..."
    
    # Debug mode
    if [[ "${1:-}" == "--debug" ]]; then
        log I "Modo debug - probando rofi..."
        if printf "Test 1\nTest 2\nTest 3" | rofi -dmenu -p "Test" >/dev/null 2>&1; then
            log S "Rofi funciona correctamente"
        else
            log E "Rofi no funciona"
            exit 1
        fi
        exit 0
    fi
    
    # Check for at least one wallpaper setter
    if ! command -v matugen >/dev/null 2>&1 && \
       ! command -v hyprctl >/dev/null 2>&1 && \
       ! command -v swww >/dev/null 2>&1 && \
       ! command -v feh >/dev/null 2>&1; then
        log E "No se encontró ningún programa para cambiar wallpapers"
        log I "Instala: matugen, hyprctl, swww, o feh"
        notify 4000 "✗ No hay programa para cambiar wallpapers" critical
        exit 1
    fi
    
    # Setup environment
    setup_directories
    
    # Generate wallpaper list (cached when possible)
    generate_wallpaper_list "$temp_file"
    
    # Launch rofi and get selection
    log I "Abriendo selector..."
    if ! selection=$(launch_rofi "$temp_file"); then
        case $? in
            1) log I "Selección cancelada"; exit 0 ;;
            *) log E "Error en rofi (código: $?)"; exit 1 ;;
        esac
    fi
    
    # Validate selection
    if [[ -z "$selection" ]]; then
        log I "Sin selección"
        exit 0
    fi
    
    # Clean the selection (remove any embedded log messages)
    selection=$(echo "$selection" | grep -v "^\[" | head -n1 | xargs)
    
    log S "Selección: $selection"
    
    # Resolve actual filename ultra-fast
    if ! actual_filename=$(resolve_filename "$selection"); then
        log E "Archivo no encontrado para: $selection"
        exit 1
    fi
    
    wallpaper_path="$WALL_DIR/$actual_filename"
    
    # Final verification and application
    if [[ ! -f "$wallpaper_path" ]]; then
        log E "Archivo no accesible: $wallpaper_path"
        exit 1
    fi
    
    # Apply wallpaper
    apply_wallpaper "$wallpaper_path"
}

# Execute with all arguments
main "$@"
