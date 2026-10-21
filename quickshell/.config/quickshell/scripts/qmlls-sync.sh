#!/usr/bin/env bash
# qmlls-sync.sh — rellena el VFS de quickshell con los `qmldir` escritos a
# mano (Core/Services, Core/Services/Brightness).
#
# Por qué: quickshell genera en $XDG_RUNTIME_DIR/quickshell/vfs/<hash>/qs el
# árbol de módulos que consume qmlls/qmllint (buildDir de `.qmlls.ini`). Para
# las carpetas que ya traen un `qmldir` en el repo, quickshell desactiva la
# síntesis y *no* lo copia al VFS, así que el editor no resuelve
# `import qs.Core.Services` (ni Brightness) y marca los servicios como
# desconocidos. Este script copia esos `qmldir` que faltan al VFS.
#
# Idempotente: solo copia lo que no existe. Sin VFS (CI, shell parada) sale 0.
# Lo invoca shell.qml al arrancar; también se puede correr a mano.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
VFS_BASE="$RUNTIME_DIR/quickshell/vfs"

[ -d "$VFS_BASE" ] || exit 0

mapfile -d '' QMLDIRS < <(find "$ROOT" -name qmldir -print0)
[ ${#QMLDIRS[@]} -gt 0 ] || exit 0

ROOT_SHELL="$(readlink -f "$ROOT/shell.qml")"

for vfs in "$VFS_BASE"/*/qs; do
    [ -d "$vfs" ] || continue
    # Cada VFS es un symlink-farm a su config: comprueba que este es el nuestro.
    [ "$(readlink -f "$vfs/shell.qml")" = "$ROOT_SHELL" ] || continue

    for qmldir in "${QMLDIRS[@]}"; do
        rel="${qmldir#"$ROOT"/}"
        dest="$vfs/$rel"
        [ -e "$dest" ] && continue
        mkdir -p "$(dirname "$dest")"
        cp -- "$qmldir" "$dest"
    done
done

exit 0
