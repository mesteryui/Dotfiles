#!/bin/bash

# Verifica si wlsunset está en ejecución
if pgrep -x "wlsunset" > /dev/null; then
    # Si está en ejecución, lo detiene
    echo "Desactivando wlsunset..."
    pkill wlsunset
else
    # Si no está en ejecución, lo inicia
    echo "Activando wlsunset..."
    wlsunset &
fi
