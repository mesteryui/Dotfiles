#!/usr/bin/env bash
# Instala Google Sans Flex (variable, OFL) en ~/.local/share/fonts.
# Idempotente: si la familia ya está registrada en fontconfig, no hace nada.
# Uso: install-google-sans-flex.sh [--force|-f] [--help|-h]

set -euo pipefail

FONT_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/googlesansflex/GoogleSansFlex%5BGRAD%2CROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf"
FONT_DIR="${HOME:?HOME no está definido}/.local/share/fonts"
FONT_FILE="$FONT_DIR/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        --help|-h) echo "Uso: $(basename "$0") [--force|-f]"; exit 0 ;;
        *) echo "Argumento desconocido: $arg" >&2; exit 1 ;;
    esac
done

is_installed() {
    # Se captura la salida completa antes de filtrar: si grep -q cierra
    # el tubo a mitad, fc-list muere por SIGPIPE y pipefail lo marcaría
    # como fallo aunque la fuente exista.
    local out
    out=$(fc-list 2>/dev/null || true)
    grep -qi "google sans flex" <<<"$out"
}

for dep in curl fc-list fc-cache file; do
    command -v "$dep" &>/dev/null || { echo "Falta dependencia: $dep" >&2; exit 1; }
done

if [[ $FORCE -eq 0 ]] && is_installed; then
    # Corrige permisos de instalaciones previas (mktemp crea con 600).
    [[ -f "$FONT_FILE" ]] && chmod 644 "$FONT_FILE" 2>/dev/null || true
    echo "Google Sans Flex ya está instalada."
    exit 0
fi

mkdir -p "$FONT_DIR"
# mktemp portable: --suffix solo existe en GNU (falla en macOS/BSD).
tmp="$(mktemp "${TMPDIR:-/tmp}/gsansflex.XXXXXX.ttf" 2>/dev/null || mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Descargando Google Sans Flex..."
curl -fSL --retry 3 --retry-all-errors --connect-timeout 15 -o "$tmp" "$FONT_URL" \
    || { echo "Error descargando la fuente (revisa tu conexión)." >&2; exit 1; }

# Sanidad: un TTF variable real (el fichero ronda los 4 MB).
# wc -c en vez de stat -c%s: funciona en GNU y BSD/macOS.
size=$(wc -c < "$tmp")
(( size > 1000000 )) || { echo "Descarga sospechosa (${size} bytes), abortando." >&2; exit 1; }
file -b "$tmp" | grep -qi "font\|opentype\|truetype" || { echo "El fichero no parece una fuente." >&2; exit 1; }

mv -f "$tmp" "$FONT_FILE"
chmod 644 "$FONT_FILE"
fc-cache -f "$FONT_DIR" >/dev/null || echo "Aviso: fc-cache falló, la fuente igual funcionará." >&2

if is_installed; then
    echo "Google Sans Flex instalada en $FONT_FILE"
else
    echo "La instalación no se refleja en fontconfig." >&2
    exit 1
fi
