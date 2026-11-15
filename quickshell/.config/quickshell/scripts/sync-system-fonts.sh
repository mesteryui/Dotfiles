#!/usr/bin/env bash
set -euo pipefail

# sync-system-fonts.sh — sistema de fuentes centralizado (inspirado en el
# sync-system-fonts.sh de Ryoku).
#
# La fuente de verdad es la config de la shell:
#   ~/.config/shinro/config.json → appearance.fontSans / appearance.monospace
# (la misma que leen los ajustes y Appearance.font.sans/mono). Este script
# la vuelca a los destinos de aplicaciones para que GTK y Qt mantengan la
# misma tipografía que la shell:
#
#   1. fontconfig → ~/.config/fontconfig/conf.d/90-shell-fonts.conf
#       aliases sans-serif/system-ui/monospace. Va en "90-" para ordenar
#       ANTES de 99-default-fonts.conf: en fontconfig el primer archivo
#       leído gana en <alias><prefer>, así que este manda.
#   2. qtengine   → ~/.config/qtengine/config.json (theme.font / fontFixed)
#   3. GTK        → gtk-3.0/gtk-4.0/settings.ini (gtk-font-name) y
#                   gsettings org.gnome.desktop.interface (libadwaita)
#
# Solo se sincroniza la FAMILIA: cada destino conserva su tamaño actual
# (GTK 11, qtengine 12; si un destino no lo tiene, 11).
#
# Uso:
#   sync-system-fonts.sh                  # lee la config de la shell
#   sync-system-fonts.sh "Familia" "Mono" # valores explícitos
#
# Idempotente (reescribe solo si algo cambió) y con flock, por si la shell
# y una ejecución manual se solapan. Las apps abiertas no recargan sus
# fuentes: el cambio surte efecto al abrirlas de nuevo.

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
lock_file="$state_home/quickshell/font-sync.lock"

usage() {
    echo "Uso: $(basename "$0") [SANS MONO]" >&2
    exit 2
}

case "$#" in
    0) ;;
    2) ;;
    *) usage ;;
esac

sans="${1-}"
mono="${2-}"

if [[ "$#" -eq 0 ]]; then
    # Sin argumentos: leer la config de la shell (fuente de verdad).
    # Una línea por familia: los nombres llevan espacios.
    mapfile -t shell_fonts < <(python3 - "$config_home/shinro/config.json" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        appearance = json.load(handle).get("appearance", {})
except (OSError, ValueError):
    appearance = {}

print(appearance.get("fontSans") or "Google Sans Flex")
print(appearance.get("monospace") or "JetBrainsMono Nerd Font")
PY
    )
    sans="${shell_fonts[0]:-Google Sans Flex}"
    mono="${shell_fonts[1]:-JetBrainsMono Nerd Font}"
fi

[[ -n "$sans" && -n "$mono" ]] || usage

# Serializar invocaciones concurrentes (la shell debouncea, pero una
# ejecución manual en paralelo podría intercalarse escrituras).
mkdir -p "$(dirname "$lock_file")"
exec 9>"$lock_file"
if ! flock -w 15 9; then
    echo "[sync-system-fonts] timeout esperando el lock $lock_file" >&2
    exit 1
fi

status=0

# Aviso, nunca error: si la familia no está instalada, fontconfig/GTK/Qt
# resolverán a un sustituto y el resultado no coincidirá con lo pedido.
if command -v fc-match >/dev/null 2>&1; then
    for family in "$sans" "$mono"; do
        resolved="$(fc-match -f '%{family[0]}' "$family" 2>/dev/null || true)"
        if [[ -n "$resolved" && "${resolved,,}" != "${family,,}" ]]; then
            echo "[sync-system-fonts] aviso: '$family' no parece instalada (resuelve a '$resolved')" >&2
        fi
    done
fi

# --- Destinos en fichero (fontconfig, qtengine, GTK settings.ini) ---------
python3 - "$config_home" "$sans" "$mono" <<'PY' || status=1
import json
import os
import re
import sys
import tempfile
from xml.sax.saxutils import escape

config_home, sans, mono = sys.argv[1], sys.argv[2], sys.argv[3]


def write_if_changed(path, content):
    """Escritura atómica que conserva el modo; True si ha cambiado."""
    try:
        with open(path, encoding="utf-8") as handle:
            if handle.read() == content:
                return False
    except FileNotFoundError:
        pass

    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o644
    fd, temp_path = tempfile.mkstemp(prefix=".sync-system-fonts.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.chmod(temp_path, mode)
        os.replace(temp_path, path)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)
    return True


# 1. fontconfig: aliases de las fuentes de la shell.
def alias_block(family, prefer):
    entries = "\n".join(f"      <family>{escape(f)}</family>" for f in prefer)
    return (
        "  <alias>\n"
        f"    <family>{escape(family)}</family>\n"
        "    <prefer>\n"
        f"{entries}\n"
        "    </prefer>\n"
        "  </alias>"
    )


fontconfig_content = (
    '<?xml version="1.0"?>\n'
    '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n'
    "<fontconfig>\n"
    "  <!-- GENERADO por scripts/sync-system-fonts.sh: no editar a mano.\n"
    "       Aliases de las fuentes elegidas en Ajustes de la shell\n"
    "       (shinro/config.json → appearance.fontSans / appearance.monospace).\n"
    "       El prefijo 90- hace que se lea antes de 99-default-fonts.conf:\n"
    "       en fontconfig el primer archivo leído gana en <alias><prefer>. -->\n"
    + alias_block("sans-serif", [sans, "Noto Sans"]) + "\n"
    + alias_block("system-ui", [sans, "Noto Sans"]) + "\n"
    + alias_block("monospace", [mono, "Noto Sans Mono"]) + "\n"
    + "</fontconfig>\n"
)
write_if_changed(
    os.path.join(config_home, "fontconfig", "conf.d", "90-shell-fonts.conf"),
    fontconfig_content,
)

# 2. qtengine (Qt): solo las familias; tamaño y peso actuales se conservan.
qtengine_path = os.path.join(config_home, "qtengine", "config.json")
if os.path.isfile(qtengine_path):
    try:
        with open(qtengine_path, encoding="utf-8") as handle:
            qtengine = json.load(handle)
    except ValueError:
        qtengine = None
        print("[sync-system-fonts] aviso: qtengine/config.json ilegible, se omite",
              file=sys.stderr)
    if qtengine is not None:
        theme = qtengine.setdefault("theme", {})
        theme.setdefault("font", {})["family"] = sans
        theme.setdefault("fontFixed", {})["family"] = mono
        write_if_changed(qtengine_path,
                         json.dumps(qtengine, indent=2, ensure_ascii=False) + "\n")

# 3. GTK: gtk-font-name conservando el tamaño que ya tenga cada destino.
for gtk_version in ("gtk-3.0", "gtk-4.0"):
    settings_path = os.path.join(config_home, gtk_version, "settings.ini")
    if not os.path.isfile(settings_path):
        continue

    with open(settings_path, encoding="utf-8") as handle:
        settings = handle.read()

    size_match = re.search(r"^gtk-font-name=.*?(\d+)\s*$", settings, re.MULTILINE)
    size = size_match.group(1) if size_match else "11"
    line = f"gtk-font-name={sans} {size}"

    if re.search(r"^gtk-font-name=.*$", settings, re.MULTILINE):
        updated = re.sub(r"^gtk-font-name=.*$", lambda _m: line, settings,
                         flags=re.MULTILINE)
    else:
        header = re.search(r"^\[Settings\]\s*$", settings, re.MULTILINE)
        if header:
            updated = (settings[:header.end()] + "\n" + line
                       + settings[header.end():])
        else:
            updated = settings.rstrip("\n") + "\n" + line + "\n"

    write_if_changed(settings_path, updated)
PY

# --- gsettings (libadwaita/GNOME) -----------------------------------------
# Cada clave conserva su propio tamaño (se lee el valor actual).
if command -v gsettings >/dev/null 2>&1 \
        && gsettings get org.gnome.desktop.interface font-name >/dev/null 2>&1; then
    sans_size="$(gsettings get org.gnome.desktop.interface font-name | tr -d "'" | awk '{print $NF}')"
    mono_size="$(gsettings get org.gnome.desktop.interface monospace-font-name | tr -d "'" | awk '{print $NF}')"
    [[ "$sans_size" =~ ^[0-9]+$ ]] || sans_size=11
    [[ "$mono_size" =~ ^[0-9]+$ ]] || mono_size=11

    gsettings set org.gnome.desktop.interface font-name "$sans $sans_size" || status=1
    gsettings set org.gnome.desktop.interface monospace-font-name "$mono $mono_size" || status=1
fi

if [[ "$status" -eq 0 ]]; then
    echo "[sync-system-fonts] aplicado: sans='$sans' mono='$mono'"
else
    echo "[sync-system-fonts] completado con errores (status=$status)" >&2
fi

exit "$status"
