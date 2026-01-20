#!/bin/bash

# Steam Launcher para Rofi con carátulas mejoradas
# Inspirado en HyDe con colores de Matugen

# Directorios
STEAM_DIR="$HOME/.steam/steam"
ROFI_DIR="$HOME/.config/rofi"
CACHE_DIR="$HOME/.cache/rofi-steam"
ICONS_DIR="$CACHE_DIR/icons"

# Crear directorios si no existen
mkdir -p "$CACHE_DIR" "$ICONS_DIR"

# Archivos
GAMES_LIST="$CACHE_DIR/games.list"
GAMES_DESKTOP="$CACHE_DIR/games"

# Función para obtener la lista de juegos de Steam
get_steam_games() {
    # Buscar archivos .acf en Steam
    find "$STEAM_DIR/steamapps" -name "*.acf" -type f | while read -r acf_file; do
        # Extraer información del archivo .acf
        app_id=$(grep -oP '"appid"\s*"\K[^"]*' "$acf_file")
        game_name=$(grep -oP '"name"\s*"\K[^"]*' "$acf_file")
        
        if [[ -n "$app_id" && -n "$game_name" ]]; then
            echo "$app_id|$game_name"
        fi
    done | sort -t'|' -k2
}

# Función para descargar y procesar carátulas de Steam
download_cover() {
    local app_id="$1"
    local cover_path="$ICONS_DIR/${app_id}.jpg"
    
    if [[ ! -f "$cover_path" ]]; then
        echo "Descargando carátula para juego ID: $app_id"
        
        # URLs de imágenes de Steam (priorizando las más grandes y de mejor calidad)
        local urls=(
            # Carátula vertical grande (600x900) - ideal para mostrar como en Steam
            "https://cdn.akamai.steamstatic.com/steam/apps/${app_id}/library_600x900.jpg"
            "https://cdn.cloudflare.steamstatic.com/steam/apps/${app_id}/library_600x900.jpg"
            "https://steamcdn-a.akamaihd.net/steam/apps/${app_id}/library_600x900.jpg"
            
            # Hero image horizontal grande
            "https://cdn.akamai.steamstatic.com/steam/apps/${app_id}/library_hero.jpg"
            "https://cdn.cloudflare.steamstatic.com/steam/apps/${app_id}/library_hero.jpg"
            "https://steamcdn-a.akamaihd.net/steam/apps/${app_id}/library_hero.jpg"
            
            # Header image
            "https://cdn.akamai.steamstatic.com/steam/apps/${app_id}/header.jpg"
            "https://cdn.cloudflare.steamstatic.com/steam/apps/${app_id}/header.jpg"
            "https://steamcdn-a.akamaihd.net/steam/apps/${app_id}/header.jpg"
            
            # Capsule grande
            "https://cdn.akamai.steamstatic.com/steam/apps/${app_id}/capsule_616x353.jpg"
            "https://cdn.cloudflare.steamstatic.com/steam/apps/${app_id}/capsule_616x353.jpg"
        )
        
        # Intentar descargar desde cada URL hasta encontrar una que funcione
        for cover_url in "${urls[@]}"; do
            echo "Intentando descargar desde: $cover_url"
            
            if command -v curl >/dev/null 2>&1; then
                if curl -s -f -L --max-time 30 -o "$cover_path" "$cover_url" 2>/dev/null; then
                    # Verificar que el archivo descargado es válido (más de 5KB para asegurar calidad)
                    if [[ -f "$cover_path" && $(stat -c%s "$cover_path" 2>/dev/null || echo 0) -gt 5120 ]]; then
                        echo "✓ Carátula descargada exitosamente"
                        break
                    else
                        echo "✗ Archivo inválido o muy pequeño"
                        rm -f "$cover_path"
                    fi
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q --spider --timeout=30 "$cover_url" 2>/dev/null && wget -q --timeout=30 -O "$cover_path" "$cover_url" 2>/dev/null; then
                    if [[ -f "$cover_path" && $(stat -c%s "$cover_path" 2>/dev/null || echo 0) -gt 5120 ]]; then
                        echo "✓ Carátula descargada exitosamente"
                        break
                    else
                        echo "✗ Archivo inválido o muy pequeño"
                        rm -f "$cover_path"
                    fi
                fi
            fi
        done
        
        # Si no se pudo descargar ninguna imagen, crear una carátula placeholder
        if [[ ! -f "$cover_path" ]]; then
            echo "⚠ No se pudo descargar carátula, creando placeholder"
            create_placeholder_cover "$app_id" "$cover_path"
        fi
        
        # Optimizar la imagen si se descargó correctamente
        if [[ -f "$cover_path" ]]; then
            optimize_cover "$cover_path"
        fi
    fi
    
    echo "$cover_path"
}

# Función para crear carátula placeholder
create_placeholder_cover() {
    local app_id="$1"
    local cover_path="$2"
    
    # Buscar icono de steam del sistema
    local system_icons=(
        "/usr/share/icons/hicolor/256x256/apps/steam.png"
        "/usr/share/pixmaps/steam.png"
        "/usr/share/icons/steam.png"
        "/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/com.valvesoftware.Steam.png"
        "/usr/share/icons/hicolor/48x48/apps/steam.png"
    )
    
    for system_icon in "${system_icons[@]}"; do
        if [[ -f "$system_icon" ]]; then
            cp "$system_icon" "$cover_path" 2>/dev/null && return
        fi
    done
    
    # Si no hay iconos del sistema, crear un SVG placeholder y convertirlo
    if command -v convert >/dev/null 2>&1; then
        local placeholder_svg="$CACHE_DIR/placeholder_${app_id}.svg"
        cat > "$placeholder_svg" <<EOF
<svg width="600" height="900" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1e293b;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#334155;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#grad)"/>
  <circle cx="300" cy="300" r="80" fill="#64748b" opacity="0.3"/>
  <text x="300" y="320" font-family="Arial, sans-serif" font-size="72" fill="#94a3b8" text-anchor="middle">🎮</text>
  <text x="300" y="500" font-family="Arial, sans-serif" font-size="32" fill="#94a3b8" text-anchor="middle">Steam Game</text>
  <text x="300" y="550" font-family="Arial, sans-serif" font-size="24" fill="#64748b" text-anchor="middle">ID: ${app_id}</text>
</svg>
EOF
        convert "$placeholder_svg" -quality 85 "$cover_path" 2>/dev/null
        rm -f "$placeholder_svg"
    else
        # Fallback: crear un archivo de texto como placeholder
        echo "Steam Game ID: $app_id" > "${cover_path}.txt"
        touch "$cover_path"
    fi
}

# Función para optimizar carátulas
optimize_cover() {
    local cover_path="$1"
    
    # Solo optimizar si ImageMagick está disponible
    if command -v convert >/dev/null 2>&1; then
        local temp_file="${cover_path}.tmp"
        
        # Redimensionar y optimizar la imagen manteniendo aspecto ratio
        # Tamaño máximo de 400x600 para mejor rendimiento en rofi
        convert "$cover_path" \
            -resize "400x600>" \
            -quality 85 \
            -strip \
            -unsharp 0x0.75+0.75+0.008 \
            "$temp_file" 2>/dev/null
        
        # Reemplazar el archivo original si la conversión fue exitosa
        if [[ -f "$temp_file" && $(stat -c%s "$temp_file" 2>/dev/null || echo 0) -gt 1024 ]]; then
            mv "$temp_file" "$cover_path"
            echo "✓ Carátula optimizada"
        else
            rm -f "$temp_file"
        fi
    fi
}

# Función para crear archivos .desktop temporales
create_desktop_files() {
    rm -rf "$GAMES_DESKTOP"
    mkdir -p "$GAMES_DESKTOP"
    
    local count=0
    local total=$(wc -l < "$GAMES_LIST")
    
    echo "Creando archivos .desktop para $total juegos..."
    
    while IFS='|' read -r app_id game_name; do
        [[ -z "$app_id" || -z "$game_name" ]] && continue
        
        count=$((count + 1))
        echo "Procesando ($count/$total): $game_name"
        
        # Descargar/verificar carátula
        cover_path=$(download_cover "$app_id")
        
        # Limpiar nombre del juego para el archivo
        safe_name=$(echo "$game_name" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g')
        desktop_file="$GAMES_DESKTOP/${safe_name}.desktop"
        
        # Crear archivo .desktop con información extendida
        cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$game_name
Comment=Jugar $game_name en Steam
Exec=steam steam://rungameid/$app_id
Icon=$cover_path
Categories=Game;ActionGame;AdventureGame;ArcadeGame;BoardGame;BlocksGame;CardGame;KidsGame;LogicGame;RolePlaying;Shooter;Simulation;SportsGame;StrategyGame;
Keywords=steam;game;gaming;juego;
StartupNotify=true
NoDisplay=false
MimeType=x-scheme-handler/steam;
Actions=Properties;Community;Store;

[Desktop Action Properties]
Name=Propiedades del juego
Exec=steam steam://nav/games/details/$app_id

[Desktop Action Community]
Name=Comunidad Steam
Exec=steam steam://url/GameHub/$app_id

[Desktop Action Store]
Name=Ver en tienda
Exec=steam steam://store/$app_id
EOF
        
        # Verificar que el archivo .desktop se creó correctamente
        if [[ ! -f "$desktop_file" ]]; then
            echo "⚠ Error creando archivo .desktop para $game_name"
        fi
        
    done < "$GAMES_LIST"
    
    echo "✓ Archivos .desktop creados: $(find "$GAMES_DESKTOP" -name "*.desktop" | wc -l)"
}

# Función para actualizar la cache de juegos
update_cache() {
    echo "🔄 Actualizando lista de juegos de Steam..."
    
    # Verificar que Steam esté instalado y tenga juegos
    if [[ ! -d "$STEAM_DIR/steamapps" ]]; then
        echo "❌ Error: Directorio de Steam apps no encontrado en $STEAM_DIR/steamapps"
        return 1
    fi
    
    # Obtener lista de juegos
    get_steam_games > "$GAMES_LIST"
    local game_count=$(wc -l < "$GAMES_LIST")
    
    if [[ $game_count -eq 0 ]]; then
        echo "⚠ No se encontraron juegos de Steam instalados"
        return 1
    fi
    
    echo "📦 Encontrados $game_count juegos"
    
    # Crear archivos .desktop
    create_desktop_files
    
    echo "✅ Cache actualizada exitosamente"
    echo "📊 Estadísticas:"
    echo "   - Juegos: $game_count"
    echo "   - Carátulas: $(find "$ICONS_DIR" -name "*.jpg" | wc -l)"
    echo "   - Archivos .desktop: $(find "$GAMES_DESKTOP" -name "*.desktop" | wc -l)"
}

# Función para lanzar rofi con configuración optimizada
launch_rofi() {
    echo "🚀 Lanzando Steam Launcher..."
    
    # Verificar que existan juegos
    if [[ ! -f "$GAMES_LIST" || $(wc -l < "$GAMES_LIST") -eq 0 ]]; then
        echo "⚠ No hay juegos en cache. Actualizando..."
        update_cache
    fi
    
    # Verificar que existe la configuración de rofi
    
    # Lanzar rofi con configuración optimizada para carátulas
    rofi -show drun \
         -drun-categories Game \
         -drun-match-fields name,generic,exec,categories,keywords \
         -drun-display-format "{name}" \
         -no-lazy-grab \
         -no-plugins \
         -drun-show-actions \
         -scroll-method 1 \
         -drun-url-launcher "xdg-open" \
         -drun-use-desktop-cache \
         -drun-reload-desktop-cache \
         -drun-parse-user true \
         -drun-parse-system false \
         -drun-desktop-cache-dir "$GAMES_DESKTOP" \
         -icon-theme "hicolor" \
         -show-icons \
         -display-drun "🎮 Steam Games"
}

# Función para limpiar cache
clean_cache() {
    echo "🧹 Limpiando cache..."
    rm -rf "$CACHE_DIR"
    echo "✅ Cache limpiada"
}

# Función para mostrar estadísticas
show_stats() {
    echo "📊 Estadísticas de Steam Launcher"
    echo "=================================="
    echo "Directorio Steam: $STEAM_DIR"
    echo "Cache: $CACHE_DIR"
    echo ""
    
    if [[ -f "$GAMES_LIST" ]]; then
        echo "Juegos encontrados: $(wc -l < "$GAMES_LIST")"
    else
        echo "Juegos encontrados: 0 (cache no inicializada)"
    fi
    
    if [[ -d "$ICONS_DIR" ]]; then
        echo "Carátulas descargadas: $(find "$ICONS_DIR" -name "*.jpg" 2>/dev/null | wc -l)"
        echo "Tamaño de carátulas: $(du -sh "$ICONS_DIR" 2>/dev/null | cut -f1)"
    else
        echo "Carátulas descargadas: 0"
    fi
    
    if [[ -d "$GAMES_DESKTOP" ]]; then
        echo "Archivos .desktop: $(find "$GAMES_DESKTOP" -name "*.desktop" 2>/dev/null | wc -l)"
    else
        echo "Archivos .desktop: 0"
    fi
}

# Función de ayuda
show_help() {
    echo "🎮 Steam Launcher para Rofi con Carátulas"
    echo "=========================================="
    echo ""
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  -u, --update     Actualizar cache de juegos y carátulas"
    echo "  -l, --launch     Lanzar rofi (por defecto)"
    echo "  -c, --clean      Limpiar cache completamente"
    echo "  -s, --stats      Mostrar estadísticas"
    echo "  -h, --help       Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0               # Lanzar rofi"
    echo "  $0 -u            # Actualizar cache y lanzar"
    echo "  $0 -c            # Limpiar cache"
    echo "  $0 -s            # Ver estadísticas"
    echo ""
    echo "Dependencias recomendadas:"
    echo "  - curl o wget (descargar carátulas)"
    echo "  - imagemagick (optimizar imágenes)"
    echo "  - rofi (launcher)"
    echo ""
}

# Función principal
main() {
    # Verificar si Steam está instalado
    if [[ ! -d "$STEAM_DIR" ]]; then
        echo "❌ Error: Steam no encontrado en $STEAM_DIR"
        echo "Asegúrate de que Steam esté instalado y se haya ejecutado al menos una vez"
        exit 1
    fi
    
    # Procesar argumentos
    case "${1:-}" in
        -u|--update)
            update_cache
            if [[ $? -eq 0 ]]; then
                launch_rofi
            fi
            ;;
        -l|--launch)
            launch_rofi
            ;;
        -c|--clean)
            clean_cache
            ;;
        -s|--stats)
            show_stats
            ;;
        -h|--help)
            show_help
            ;;
        "")
            # Si no existe cache, actualizarla
            if [[ ! -f "$GAMES_LIST" ]]; then
                echo "🔄 Inicializando cache por primera vez..."
                update_cache
            fi
            launch_rofi
            ;;
        *)
            echo "❌ Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal con todos los argumentos
main "$@"
