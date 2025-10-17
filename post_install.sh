#!/usr/bin/env bash

set -euo pipefail
set -e

IFS=$'\n\t'

# Este script está pensado para Arch Linux.
# Instala paru, aplica configs con stow y pone los paquetes necesarios.

install_paru() {
    echo "Instalando dependencias base para compilar paru..."
    sudo pacman -S --needed --noconfirm base-devel git

    echo "Clonando el repositorio de paru en /opt/paru..."
    sudo git clone https://aur.archlinux.org/paru.git /opt/paru
    sudo chown -R "$USER":"$USER" /opt/paru

    cd /opt/paru
    echo "Construyendo e instalando paru..."
    makepkg -si --noconfirm
    cd - > /dev/null
}

add_configs() {
    echo "Aplicando configuraciones con stow..."
    # Si quieres que falle si alguna no existe, añade 'set -e'
    stow hypr
    stow rofi
    stow systemd
    stow kitty
    stow fastfetch
    stow emacs
    stow waybar
    stow yazi
    stow matugen
    stow zathura
    stow lsd
    stow cava
    stow swayosd
    stow swaync
    stow fish
    stow starship
    stow bash
    stow btop
    stow uwsm
    stow bat
}
enable_system_user() {
	systemctl --user enable hypridle swaync waybar swayosd hyprpolkitagent swww 
}
enable_chaotic_AUR() {
    echo "Añadiendo claves criptograficas"
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    echo "Añadiendo paquetes de repositorios y claves"
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    sudo tee -a /etc/pacman.conf <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    echo "Actualizando sistema y repositorios"
    sudo pacman -Syu
}
install_software_notAUR() {
    echo "Habilitando los repositorios de Chaotic-AUR"
    enable_chaotic_AUR
    echo "Instalando paquetes de repositorios oficiales..."
    if [[ ! -f pkglists-repos.txt ]]; then
        echo "ERROR: El archivo pkglists-repos.txt no existe."
        exit 1
    fi
    sudo pacman -S --needed - < pkglists-repos.txt
    rustup default stable
}

install_AUR_software() {
    echo "Instalando paquetes desde AUR con paru..."
    if [[ ! -f pklist-aur.txt ]]; then
        echo "ERROR: El archivo pklist-aur.txt no existe."
        exit 1
    fi
    paru -S --needed - < pklist-aur.txt
}

main() {
    echo "Empezando la instalación y configuración..."

    install_software_notAUR
    add_configs

    if ! command -v paru &> /dev/null; then
        echo "Paru no está instalado. ¿Quieres instalarlo ahora? (s/n): "
        read -r respuesta
        if [[ "$respuesta" =~ ^[Ss]$ ]]; then
            install_paru
            install_AUR_software
        else
            echo "No se instalará paru ni los paquetes AUR."
        fi
    else
        echo "Paru ya está instalado. Instalando paquetes AUR..."
        install_AUR_software
    fi

    echo "¡Todo listo! Disfruta tu Arch configurado."
}

main

