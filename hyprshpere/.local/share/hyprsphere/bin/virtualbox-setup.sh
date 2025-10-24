#!/bin/bash
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"Instalacion de Steam"

sudo -v || exit 1

gum confirm "¿Quieres instalar VirtualBox?"

gum spin --spinner dot --title "Instalando Virtualbox host modules" -- sudo pacman -S virtualbox-host-modules-arch --noconfirm && echo "Virtualbox host modules instalado"

gum spin --spinner dot --title "Instalando Virtualbox" -- sudo pacman -S virtualbox && echo "Virtualbox instalado"

sudo usermod -aG vboxusers $USER


