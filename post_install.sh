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
    stow hypr
    stow rofi
    stow kitty
    stow fastfetch
    stow emacs
    stow waybar
    stow yazi
    stow matugen
    stow zathura
}
install_software_notAUR() {
    echo "Instalando programas varios...."
    sudo pacman -S waybar rofi-wayland hypr kitty yazi ly --noconfirm
    echo "Instalando packs de iconos y tipografias"
    sudo pacman -S papirus-icon-theme ttf-jetbrains-mono-nerd ttf-font-awesome
}
install_AUR_software() {
    paru -S matugen-bin
}
echo "Primero antes que nada colocaremos los archivos de configuracion"
add_configs
if ! pacman -Q paru &>/dev/null; then
    echo "Paru no esta instalado tenga en cuenta que para continuar, debera instalar cosas desde AUR si no las tiene se recomienda instalacion. Desea instalar paru /n"
    read prompt
    if [ prompt -eq "s"] then
       install_paru
       install_AUR_software
else
    echo "El paquete nombre_del_paquete SÍ está instalado."
fi
