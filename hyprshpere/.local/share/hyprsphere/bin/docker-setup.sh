#!/bin/bash

echo "Introduzca su contraseña para continuar"

read -s -p "Password: " pass
echo

echo "Iniciando instalacion de docker y docker compose"
echo $pass | sudo -S pacman -S --noconfirm docker docker-compose

echo "Añadiendo usuario al grupo docker"
echo $pass | sudo -S usermod -aG docker $USER

echo "Habilitando el servicio docker"
echo $pass | sudo -S systemctl enable docker
