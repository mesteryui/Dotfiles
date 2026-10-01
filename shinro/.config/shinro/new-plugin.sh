#!/bin/sh
# new-plugin.sh — crea un plugin de shinro (ver PLUGINS.md).
# Uso: new-plugin.sh <id> "<Nombre>" [type]
# Crea ~/.config/shinro/plugins/<id>/ con plugin.json + esqueleto QML.
# Fase 1: solo type=launcher se instancia (el resto se lista).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGINS="$DIR/plugins"
ID="${1:-}"
NAME="${2:-$ID}"
TYPE="${3:-launcher}"
if [ -z "$ID" ]; then
  echo "Uso: $0 <id> \"<Nombre>\" [type]" >&2
  echo "Ej:  $0 mis-notas \"Mis notas\" launcher" >&2
  exit 1
fi
case "$ID" in
  *[^a-z0-9_-]*|""|.*|*-|-*)
    echo "id inválido '$ID': ^[a-z0-9][a-z0-9_-]*\$ (empieza por letra/número)" >&2
    exit 1
    ;;
esac
case "$ID" in
  main|todo|system|files|web|emoji|calc|clip|powerprofiles|fastfetch|animations|plugins)
    echo "id reservado '$ID': elige otro" >&2
    exit 1
    ;;
esac
case "$TYPE" in
  launcher|bar-widget|panel|daemon) ;;
  *)
    echo "type inválido '$TYPE': launcher|bar-widget|panel|daemon" >&2
    exit 1
    ;;
esac
DEST="$PLUGINS/$ID"
if [ -e "$DEST" ]; then
  echo "Ya existe: $DEST" >&2
  exit 1
fi
mkdir -p "$DEST"
# Escape para JSON (\" y \\). Sin comillas simples en los valores.
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
ID_ESC="$(esc "$ID")"
NAME_ESC="$(esc "$NAME")"
SEC_ESC="$(printf '%s' "$ID" | tr '_' '-')"
cat > "$DEST/plugin.json" <<EOF
{
    "id": "$ID_ESC",
    "name": "$NAME_ESC",
    "description": "$NAME_ESC",
    "version": "1.0.0",
    "author": "",
    "type": "$TYPE",
    "capabilities": [],
    "component": "./Main.qml",
    "requires_shinro": ">=1.0",
    "permissions": []
}
EOF
if [ "$TYPE" = "launcher" ]; then
  cat > "$DEST/Main.qml" <<EOF
// Menú plugin "$NAME_ESC" (sectionId "$SEC_ESC").
// Contrato: MenuDefinition como raíz (ver PLUGINS.md). Se aplica al
// abrir el launcher o con: qs ipc call plugins reload $ID_ESC

import qs.Launcher

MenuDefinition {
    sectionId: "$SEC_ESC"
    titleFallback: "$NAME_ESC"
    iconName: "extension"
    parentId: "main"

    entries: [
        shell("hola", "Hola mundo", "entrada de ejemplo", "waving_hand", "notify-send '$NAME_ESC' 'Funciona'"),
        submenu("volver", "Volver", "al menú Sistema", "arrow_back", "main")
    ]
}
EOF
elif [ "$TYPE" = "bar-widget" ]; then
  cat > "$DEST/Main.qml" <<EOF
// Widget de barra "$NAME_ESC" (ver PLUGINS.md).
// Raíz Item con tamaño implícito; se instancia una vez por pantalla
// al final de su zone. \`property var plugin\` es opcional (si no
// está, usa PluginService.* directamente con tu id "$ID_ESC").

import qs.Core
import QtQuick

Item {
    property var plugin

    implicitWidth: 120
    implicitHeight: 36

    Text {
        anchors.centerIn: parent
        text: "$NAME_ESC"
        color: Appearance.md3.on_surface
    }
}
EOF
elif [ "$TYPE" = "panel" ]; then
  cat > "$DEST/Main.qml" <<EOF
// Panel "$NAME_ESC" (ver PLUGINS.md). El host le pone ventana, fondo,
// foco y Escape; aquí solo el contenido (llenar al padre + tamaño).
// Apertura: qs ipc call plugins open-panel $ID_ESC

import QtQuick

Item {
    property var plugin

    anchors.fill: parent
    implicitWidth: 320
    implicitHeight: 200
}
EOF
else
  cat > "$DEST/Main.qml" <<EOF
// Daemon "$NAME_ESC" (ver PLUGINS.md). Raíz Item no visible (QtObject
// no admite hijos directos): una instancia viva hasta el rescan.
// Puede declarar IpcHandler propio con target único.
// \`property var plugin\` es opcional.

import QtQuick
import Quickshell

Item {
    property var plugin
    visible: false

    property Timer ticker: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: console.log("$ID_ESC: tick")
    }
}
EOF
fi
echo "Creado: $DEST (id='$ID', type='$TYPE')"
if [ "$TYPE" = "launcher" ]; then
  echo "Se aplica al abrir el launcher. Ver: qs ipc call plugins list"
else
  echo "Superficie '$TYPE' activa. Ver: qs ipc call plugins list"
fi
