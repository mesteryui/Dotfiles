#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprctl &>/dev/null; then
    echo "Error: hyprctl no encontrado. ¿Está Hyprland en ejecución?" >&2
    exit 1
fi

HYPRGAMEMODE="$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')"
if [[ "$HYPRGAMEMODE" == "1" ]]; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword animation borderangle,0; \
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword decoration:fullscreen_opacity 1;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0;\
        keyword decoration:active_opacity 1;\
        keyword decoration:inactive_opacity 1"
    hyprctl notify 1 5000 "rgb(40a02b)" "fontsize:15 Gamemode [ON]"
    exit 0
else
    hyprctl notify 1 5000 "rgb(d20f39)" "fontsize:15 Gamemode [OFF]"
    hyprctl reload
    exit 0
fi
