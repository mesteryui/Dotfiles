#!/bin/sh
# new-menu.sh — crea un menú personalizado sobre el componente CustomMenu.
# Uso: new-menu.sh MiMenu "Mi menú" [parentId] [icono]
# Crea MenuProviders/MiMenu.qml. Se aplica al abrir el launcher.
# Los 6 modos fijos (Archivos, Aplicaciones, Calculadora, Web, Emojis,
# Clipboard) NO se crean aquí; esto es solo para menús del sistema (>).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
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
# Escape para QML (\" y \\). Sin comillas simples en los valores.
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
SEC_ESC="$(esc "$SECTION")"
TITLE_ESC="$(esc "$TITLE")"
PARENT_ESC="$(esc "$PARENT")"
ICON_ESC="$(esc "$ICON")"
cat > "$DEST" <<EOF
// Menú personalizado sobre CustomMenu (ver Launcher/CustomMenu.qml).
// Se aplica al abrir el launcher (comprueba cambios en disco).

import qs.Launcher

CustomMenu {
    sectionId: "$SEC_ESC"
    titleFallback: "$TITLE_ESC"
    iconName: "$ICON_ESC"
    parentId: "$PARENT_ESC"

    entries: [
        shell("ejemplo-web", "Abrir web", "https://ejemplo.com", "open_in_new", "xdg-open https://ejemplo.com"),
        submenu("ejemplo-sub", "Submenú", "navega a otra sección", "arrow_forward", "main")
    ]
}
EOF
echo "Creado: $DEST (sectionId='$SECTION', parent='$PARENT')"
echo "Se aplica al abrir el launcher. Para forzar: qs ipc call launcher reloadMenus"
