#!/bin/bash

# Verifica si wlsunset está en ejecución
if pgrep -x "hyprsunset" > /dev/null; then
    # Si está en ejecución, lo detiene
    echo "Desactivando wlsunset..."
    pkill hyprsunset
else
    # Si no está en ejecución, lo inicia
    echo "Activando wlsunset..."
    hyprsunset &
fi
