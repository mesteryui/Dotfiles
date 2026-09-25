#!/usr/bin/env bash
# Instala Google Sans Flex (variable, OFL) en ~/.local/share/fonts.
# Idempotente: si la familia ya está registrada en fontconfig, no hace nada.
# Uso: install-google-sans-flex.sh [--force]

set -euo pipefail

FONT_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/googlesansflex/GoogleSansFlex%5BGRAD%2CROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf"
FONT_DIR="$HOME/.local/share/fonts"
FONT_FILE="$FONT_DIR/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
FORCE=0

if [[ "${1:-}" == "--force" ]]; then FORCE=1; fi

is_installed() {
    # Se captura la salida completa antes de filtrar: si grep -q cierra
    # el tubo a mitad, fc-list muere por SIGPIPE y pipefail lo marcaría
    # como fallo aunque la fuente exista.
    local out
    out=$(fc-list 2>/dev/null)
    grep -qi "google sans flex" <<<"$out"
}

for dep in curl fc-list fc-cache; do
    command -v "$dep" &>/dev/null || { echo "Falta dependencia: $dep" >&2; exit 1; }
done

if [[ $FORCE -eq 0 ]] && is_installed; then
    echo "Google Sans Flex ya está instalada."
    exit 0
fi

mkdir -p "$FONT_DIR"
tmp="$(mktemp --suffix=.ttf)"
trap 'rm -f "$tmp"' EXIT

echo "Descargando Google Sans Flex..."
curl -fSL --retry 3 -o "$tmp" "$FONT_URL"

# Sanidad: un TTF variable real (el fichero ronda los 4 MB)
size=$(stat -c%s "$tmp")
(( size > 1000000 )) || { echo "Descarga sospechosa (${size} bytes), abortando." >&2; exit 1; }
file -b "$tmp" | grep -qi "font\|opentype\|truetype" || { echo "El fichero no parece una fuente." >&2; exit 1; }

mv -f "$tmp" "$FONT_FILE"
fc-cache -f "$FONT_DIR" >/dev/null

if is_installed; then
    echo "Google Sans Flex instalada en $FONT_FILE"
else
    echo "La instalación no se refleja en fontconfig." >&2
    exit 1
fi
