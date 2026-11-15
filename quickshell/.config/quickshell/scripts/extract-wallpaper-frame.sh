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
# Optimizado:
# - Fast seek con -noaccurate_seek -ss 1 (salta por keyframe sin decodificar previo)
# - Escalado acelerado a máx 1280px con fast_bilinear (archivos más ligeros y decodificación ultra-rápida)
# - Multi-hilo (-threads 4)

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

# Extracción acelerada y optimizada
if ffmpeg -y -v error -noaccurate_seek -ss 1 -i "$video" -frames:v 1 -vf "scale=min(1280\,iw):-2:flags=fast_bilinear" -threads 4 -q:v 4 "$tmp"; then
    mv -f "$tmp" "$out"
    exit 0
else
    rm -f "$tmp"
    exit 1
fi
