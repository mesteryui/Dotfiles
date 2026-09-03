#!/bin/bash
source lib.sh
gum confirm "¿Deseas instalar docker?"

if [ $? -eq 0 ]; then
echo "Introduzca su contraseña para continuar"

sudo -v || exit 1  # valida la contraseña una vez

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"Iniciando instalacion de docker y docker compose"

gum spin --spinner dot --title "Instalando docker" -- sudo pacman -S --noconfirm docker && echo "Docker instalado"

gum spin --spinner dot --title "Instalando docker compose" -- sudo pacman -S --noconfirm docker-compose && echo "Docker compose instalado"

echo "Añadiendo usuario al grupo docker"
sudo usermod -aG docker $USER
echo "Usuario añadido con exito al grupo docker"

echo "Habilitando el servicio docker"
sudo -S systemctl enable docker
echo "Servicio habilitado con exito"

echo -n "Pulse cualquier tecla para continuar...";read -n 1;exit
fi
