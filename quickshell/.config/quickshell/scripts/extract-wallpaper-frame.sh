#!/usr/bin/env bash
# extract-wallpaper-frame.sh — extrae un frame fijo (segundo 1) de un vídeo
# para usarlo como poster estático (fondo fallback, lockscreen, matugen).
#
# Uso: extract-wallpaper-frame.sh <video> <salida.jpg>
#
# Idempotente: si la salida existe y es más nueva que el vídeo, no reescribe
# nada (evita escrituras repetidas al alternar entre los mismos fondos).
# Cada vídeo siempre mapea al mismo archivo de salida (el llamador genera el
# nombre de forma determinista a partir de la ruta del vídeo).
#
# Sale 0 si la salida queda lista (extraída o ya vigente), != 0 si falla.

set -u

video="${1:-}"
out="${2:-}"

if [ -z "$video" ] || [ -z "$out" ]; then
    echo "uso: $0 <video> <salida.jpg>" >&2
    exit 2
fi

if [ ! -f "$video" ]; then
    echo "no existe: $video" >&2
    exit 1
fi

mkdir -p "$(dirname "$out")" || exit 1

# Ya vigente: no tocar el disco.
if [ -f "$out" ] && [ "$out" -nt "$video" ]; then
    exit 0
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "falta ffmpeg" >&2
    exit 1
fi

tmp="${out%.*}.tmp.$$.jpg"
# -ss 1: frame fijo del segundo 1 (patrón uniforme para todos los fondos).
if ffmpeg -y -v error -ss 1 -i "$video" -frames:v 1 -q:v 3 "$tmp"; then
    mv -f "$tmp" "$out"
    exit 0
else
    rm -f "$tmp"
    exit 1
fi
