#!/bin/bash 
echo "Instalando python-pip y python-pipx"
sudo pacman -S python-pip python-pipx
echo "Instalando linter y servidor LSP"
pipx install pyright ruff
