#!/usr/bin/env bash

install_paru() {
    sudo pacman -S base-devel git
    cd /opt/
    sudo git clone https://aur.archlinux.org/paru.git
    sudo chown -R $USER:$USER paru-git/
    cd paru
    makepkg -si
}

add_configs() {
    
}
