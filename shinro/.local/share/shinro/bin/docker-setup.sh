#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if ! command -v gum &>/dev/null; then
    echo "Error: 'gum' no está instalado." >&2
    exit 1
fi

if ! gum confirm "¿Deseas instalar docker?"; then
    echo "Cancelado."
    exit 0
fi

echo "Introduzca su contraseña para continuar"

sudo -v || exit 1 # valida la contraseña una vez

gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "Iniciando instalacion de docker y docker compose"

spin "Instalando docker" sudo pacman -S --needed --noconfirm docker
echo "Docker instalado"

spin "Instalando docker compose" sudo pacman -S --needed --noconfirm docker-compose
echo "Docker compose instalado"

echo "Añadiendo usuario al grupo docker"
sudo usermod -aG docker "${SUDO_USER:-$USER}"
echo "Usuario añadido con exito al grupo docker"

echo "Habilitando el servicio docker"
sudo systemctl enable --now docker.service
echo "Servicio habilitado con exito"

echo -n "Pulse cualquier tecla para continuar..."
read -n 1 -r -s
echo
