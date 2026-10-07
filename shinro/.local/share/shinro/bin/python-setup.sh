#!/usr/bin/env bash
set -euo pipefail

echo "Instalando python-pip y python-pipx"
sudo pacman -S --needed --noconfirm python-pip python-pipx

echo "Instalando linter y servidor LSP"
pipx install pyright
pipx install ruff
