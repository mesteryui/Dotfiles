#!/bin/bash

# Este script debe ser llamado por matugen en lugar de launch.sh directamente

# Ejecutar launch.sh de forma completamente independiente
setsid "$HOME/.local/bin/launch.sh" < /dev/null > /dev/null 2>&1 &

# Terminar inmediatamente para no bloquear matugen
exit 0
