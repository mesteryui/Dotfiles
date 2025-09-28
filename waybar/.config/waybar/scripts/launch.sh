#!/bin/bash

# Script de lanzamiento de Waybar completamente asíncrono
# Puede ser llamado directamente por matugen sin bloqueo
CACHE_DIR="$HOME/.cache/hyprsphere"
if [[ ! -d $CACHE_DIR ]]; then
    echo -e "Directorio de cache creado porque no existia"
    mkdir -p $CACHE_DIR
fi
LAYOUT_DIR="$HOME/.config/waybar/layouts"
CURRENT="$CACHE_DIR/waybar-layout.txt"
DEFAULT="default"
LOGFILE="/tmp/waybar-launch.log"

# Función para log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Función principal optimizada para velocidad
launch_waybar() {
    log_message "Iniciando proceso de lanzamiento de waybar"
    # Leer layout (más rápido que verificar si existe)
    layout=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")
    layout_path="$LAYOUT_DIR/$layout"

    # Verificación rápida de archivos (en paralelo)
    if [[ ! -f "$layout_path/config.jsonc" || ! -f "$layout_path/style.css" ]]; then
        log_message "ERROR: Archivos de configuración no encontrados en $layout_path"
        return 1
    fi
    
    # Lock simple y rápido
    local lockfile="/tmp/waybar-launch.lock"
    if ! (set -C; echo $ > "$lockfile") 2>/dev/null; then
        log_message "Otra instancia en ejecución, saliendo"
        return 0
    fi
    
    # Terminación agresiva de waybar existente
    #pkill -9 -x waybar 2>/dev/null
    #systemctl restart --user waybar
    # Espera mínima pero efectiva
    sleep 0.1
    
    # Verificar y forzar terminación si es necesario
    #if pgrep -x waybar >/dev/null; then
    #    pkill -9 -x waybar 2>/dev/null
    #    sleep 0.2
    #fi
    
    log_message "Iniciando waybar con layout: $layout"
    
    # Iniciar waybar inmediatamente
    waybar -s "$layout_path/style.css" -c "$layout_path/config.jsonc" \
        </dev/null >/dev/null 2>&1 &
    
    log_message "Waybar iniciado con PID: $!"
    
    # Limpiar lock inmediatamente (no esperar verificación)
    rm -f "$lockfile"
}

# Si se llama con --sync, ejecutar de forma síncrona (para debugging)
if [[ "$1" == "--sync" ]]; then
    launch_waybar
else
    # Ejecutar de forma completamente asíncrona
    launch_waybar </dev/null >/dev/null 2>&1 &
    disown

    # El script termina inmediatamente, waybar continúa en segundo plano
    exit 0
fi
