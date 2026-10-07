#!/usr/bin/env bash
set -euo pipefail

gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "Instalacion de VirtualBox"

sudo -v || exit 1

if ! gum confirm "¿Quieres instalar VirtualBox?"; then
    echo "Cancelado."
    exit 0
fi

gum spin --spinner dot --title "Instalando Virtualbox host modules" -- sudo pacman -S --needed --noconfirm virtualbox-host-modules-arch && echo "Virtualbox host modules instalado"

gum spin --spinner dot --title "Instalando Virtualbox" -- sudo pacman -S --needed --noconfirm virtualbox && echo "Virtualbox instalado"

sudo usermod -aG vboxusers "${SUDO_USER:-$USER}"
echo "Usuario añadido al grupo vboxusers. Reinicia la sesión para aplicar los cambios."
