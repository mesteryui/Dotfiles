
#!/bin/bash

# Detectar el primer reproductor activo
player=$(playerctl -l 2>/dev/null | head -n 1)

# Si no hay reproductores disponibles
if [[ -z "$player" ]]; then
    echo "  Ningún reproductor activo"
    exit 0
fi

# Obtener el estado (Playing, Paused, etc.)
status=$(playerctl -p "$player" status 2>/dev/null)

# Elegir icono según estado
if [[ "$status" == "Playing" ]]; then
    icon="▷  "
elif [[ "$status" == "Paused" ]]; then
    icon="  "
else
    icon="  "
fi

# Obtener metadatos de la canción o medio
song_info=$(playerctl -p "$player" metadata --format "{{title}}      {{artist}}" 2>/dev/null)

# Si no hay información (por ejemplo un vídeo sin metadatos)
if [[ -z "$song_info" ]]; then
    song_info="$player"
fi

# Mostrar el resultado
echo "${icon}${song_info}"
