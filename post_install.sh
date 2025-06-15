#!/usr/bin/env bash

set -euo pipefail
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
    stow kitty
    stow fastfetch
    stow emacs
    stow waybar
    stow yazi
    stow matugen
    stow zathura
    stow bat
    stow lsd
    stow cava
}

install_software_notAUR() {
    echo "Instalando paquetes de repositorios oficiales..."
    if [[ ! -f pkglists-repos.txt ]]; then
        echo "ERROR: El archivo pkglists-repos.txt no existe."
        exit 1
    fi
    sudo pacman -S --needed - < pkglists-repos.txt
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
        echo -n "Paru no está instalado. ¿Quieres instalarlo ahora? (s/n): "
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

