# lib.sh — funciones comunes para los scripts de shinro
# Uso: source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# spin <titulo> <comando...>
# Ej: spin "Instalando docker" sudo pacman -S --noconfirm docker
spin() {
    local title="$1"
    shift
    gum spin --spinner dot --title "$title" -- "$@"
}
