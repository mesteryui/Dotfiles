#!/usr/bin/env bash

LAYOUT_DIR="$HOME/.config/waybar/layouts"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"  # fallback si XDG_CACHE_HOME no está
CURRENT="$CACHE_DIR/hyprsphere/waybar-layout.txt"
DEFAULT="default"  # layout por defecto
layout=$(cat "$CURRENT" 2>/dev/null || echo "$DEFAULT")
layout_path="$LAYOUT_DIR/$layout"
waybar -s "$layout_path/style.css" -c "$layout_path/config.jsonc"
