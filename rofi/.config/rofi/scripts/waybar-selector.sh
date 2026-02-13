WAYBAR_DIR="$HOME/.config/waybar"
LAYOUT_DIR="$WAYBAR_DIR/layouts"
CONFIG_FILE="config.jsonc"
STYLE_FILE="style.css"
CURRENT=$(basename $(dirname $(readlink -f "$WAYBAR_DIR/$CONFIG_FILE" 2>/dev/null)))

LAYOUTS=()
for file in "$LAYOUT_DIR"/*; do
  current_file=$(basename "$file")
  if [ "$current_file" == "$CURRENT" ]; then
    LAYOUTS+=("| $current_file")
  else  
     LAYOUTS+=("$current_file")
  fi
done

SELECTED=$(printf "%s\n" "${LAYOUTS[@]}" | rofi -dmenu -p "Waybar:")

if [[ -n "$SELECTED" ]]; then
  SELECTED=${SELECTED#* }
  ln -sf "$LAYOUT_DIR/$SELECTED/$CONFIG_FILE" "$WAYBAR_DIR/$CONFIG_FILE"
  ln -sf "$LAYOUT_DIR/$SELECTED/$STYLE_FILE" "$WAYBAR_DIR/$STYLE_FILE"
  systemctl restart --user waybar
  notify-send "Cambio de Layout (Waybar)" "Cambio a $SELECTED"
fi
