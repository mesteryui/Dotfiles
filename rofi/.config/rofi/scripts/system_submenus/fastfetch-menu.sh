#!/usr/bin/env bash
FASTFETCH_DIR=$XDG_CONFIG_HOME/fastfetch
LAYOUTS_DIR=$FASTFETCH_DIR/layouts
CONFIG_FILE="config.jsonc"
CURRENT_LAYOUT=$(basename $(readlink -f "$FASTFETCH_DIR"/"$CONFIG_FILE"))
layouts=()
for file in "$LAYOUTS_DIR"/*; do
    current=$(basename "$file")
    current_cleaned=${current%.*}
    if [ "$current" == "$CURRENT_LAYOUT" ]; then
	layouts+=("| $current_cleaned")
    else
	layouts+=(" $current_cleaned")
    fi
done

opcion=$(printf "%s\n" "${layouts[@]}" | rofi -dmenu -theme ~/.config/rofi/layouts/minimal.rasi -p "Fastfetch layouts:")

if [[ -n "$opcion" ]]; then
   opcion="${opcion#* }"
   ln -sf "$LAYOUTS_DIR/${opcion}.jsonc" "$FASTFETCH_DIR/$CONFIG_FILE"
   notify-send "Cambio de layout" "Layout de fastfetch cambiado a $opcion"
fi
