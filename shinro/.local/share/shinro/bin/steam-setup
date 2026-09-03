#!/bin/bash

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"Instalacion de Steam"

sudo -v || exit 1

gum confirm "¿Quieres instalar Steam?"

if [ $? -eq 0 ]; then
    gum spin --spinner dot --title "Instalando Steam" -- sudo pacman -S --noconfirm steam
fi
echo -n "Pulse cualquier tecla para finalizar"; read -n 1 -s;exit
