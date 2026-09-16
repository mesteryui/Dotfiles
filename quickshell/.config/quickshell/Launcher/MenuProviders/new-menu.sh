#!/bin/sh
# new-menu.sh — crea un menú personalizado del SISTEMA ÚNICO.
# Uso: new-menu.sh MiMenu "Mi menú" [parentId] [icono]
# Crea MenuProviders/MiMenu.qml desde la plantilla MenuProvider.qml.
# Los 6 modos fijos (Archivos, Aplicaciones, Calculadora, Web, Emojis,
# Clipboard) NO se crean aquí; esto es solo para menús del sistema (>).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$DIR/MenuProvider.qml"
NAME="${1:-}"
TITLE="${2:-$NAME}"
PARENT="${3:-main}"
ICON="${4:-menu}"
if [ -z "$NAME" ]; then
  echo "Uso: $0 NombreMenu \"Título\" [parentId] [icono]" >&2
  echo "Ej:  $0 Proyectos \"Proyectos\" main folder" >&2
  exit 1
fi
case "$NAME" in
  *[^A-Za-z0-9_-]*)
    echo "Nombre inválido: usa letras, números, _ o - (sin espacios ni .qml)" >&2
    exit 1
    ;;
esac
# sectionId en minúsculas-guiones para evitar colisiones tontas
SECTION="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
DEST="$DIR/$NAME.qml"
if [ -e "$DEST" ]; then
  echo "Ya existe: $DEST" >&2
  exit 1
fi
# Protege sectionIds reservados (modos fijos + dinámicos + main)
case "$SECTION" in
  main|todo|system|files|web|emoji|calc|clip|powerprofiles|fastfetch|animations)
    echo "sectionId reservado '$SECTION': elige otro nombre" >&2
    exit 1
    ;;
esac
esc() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }
SEC_ESC="$(esc "$SECTION")"
TITLE_ESC="$(esc "$TITLE")"
PARENT_ESC="$(esc "$PARENT")"
ICON_ESC="$(esc "$ICON")"
# Genera el .qml sustituyendo solo las 4 propiedades cabecera
awk -v sec="$SEC_ESC" -v tit="$TITLE_ESC" -v par="$PARENT_ESC" -v ico="$ICON_ESC" '
  /property string sectionId:/ { print "    property string sectionId: \x27" sec "\x27"; next }
  /property string titleFallback:/ { print "    property string titleFallback: \x27" tit "\x27"; next }
  /property string iconName:/ { print "    property string iconName: \x27" ico "\x27"; next }
  /property string parentId:/ { print "    property string parentId: \x27" par "\x27"; next }
  { print }
' "$TEMPLATE" > "$DEST"
echo "Creado: $DEST (sectionId='$SECTION', parent='$PARENT')"
echo "Edita entries[] y recarga el shell."
