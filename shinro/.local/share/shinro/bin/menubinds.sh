#!/bin/bash

# A script to display Hyprland keybindings defined in your configuration
# using walker for an interactive search menu.
#
# Updated for Hyprland >= 0.56, whose `hyprctl -j binds` schema changed:
#   - `modmask` is now just a bool; the real modifier-mask number moved to `submap`.
#   - `submap_universal` now holds the actual named submap (e.g. "resize"), if any.
#   - `keycode` is now a human-readable key name ("right", "L", "escape",
#     "mouse:272", "XF86AUDIORAISEVOLUME"...) instead of a raw X11 keycode,
#     so we no longer need xkbcli / keycode->symbol translation at all.
#   - `description` is always the literal string "false"; the real bind
#     description (from your Lua config) lands in `allow_input_capture`.
#   - `dispatcher` is always "__lua" and `arg` is an opaque internal handle,
#     not a real command, so we can no longer reconstruct the action text
#     from dispatcher+arg — we rely entirely on `allow_input_capture`.

SEP=$'\x1f' # unit separator: safe even if descriptions contain commas/spaces

# WORKAROUND: Hyprland 0.56's `hyprctl -j binds` emits invalid JSON — string
# values for fields like `keycode` and `allow_input_capture` are printed
# WITHOUT quotes whenever they're symbolic (e.g. `"keycode": right,` instead
# of `"keycode": "right",`). This wraps any such bareword/bare-phrase value
# in quotes before handing the output to jq. Leaves true/false/null/numbers/
# already-quoted strings untouched.
sanitize_binds_json() {
  awk '
  {
    line = $0
    if (match(line, /^[[:space:]]*"[A-Za-z_]+"[[:space:]]*:[[:space:]]*/)) {
      prefix = substr(line, 1, RLENGTH)
      rest = substr(line, RLENGTH + 1)
      trail = ""
      if (rest ~ /,[[:space:]]*$/) { trail = ","; sub(/,[[:space:]]*$/, "", rest) }
      if (rest !~ /^(true|false|null|-?[0-9]+(\.[0-9]+)?|".*")$/) {
        gsub(/"/, "\\\"", rest)
        rest = "\"" rest "\""
      }
      print prefix rest trail
    } else {
      print line
    }
  }'
}

# Fetch dynamic keybindings from Hyprland and pre-format them.
# Only binds that carry a real description are shown (everything else has
# no user-facing text to fall back on anymore).
dynamic_bindings() {
  hyprctl -j binds |
    sanitize_binds_json |
    jq -r --arg sep "$SEP" '
      .[] |
      select((.allow_input_capture // "") != "" and (.allow_input_capture // "") != "false") |
      [
        (.submap // "0"),
        (.submap_universal // ""),
        (.keycode // .key // ""),
        (.allow_input_capture // .description // ""),
        (.dispatcher // ""),
        (.arg // "")
      ] | join($sep)
    '
}

# Map the numeric modmask (now living in the `submap` field) to readable text.
parse_modmask() {
  case "$1" in
    0)  echo "" ;;
    1)  echo "SHIFT" ;;
    4)  echo "CTRL" ;;
    5)  echo "SHIFT CTRL" ;;
    8)  echo "ALT" ;;
    9)  echo "SHIFT ALT" ;;
    12) echo "CTRL ALT" ;;
    13) echo "SHIFT CTRL ALT" ;;
    64) echo "SUPER" ;;
    65) echo "SUPER SHIFT" ;;
    68) echo "SUPER CTRL" ;;
    69) echo "SUPER SHIFT CTRL" ;;
    72) echo "SUPER ALT" ;;
    73) echo "SUPER SHIFT ALT" ;;
    76) echo "SUPER CTRL ALT" ;;
    77) echo "SUPER SHIFT CTRL ALT" ;;
    *)  echo "MOD($1)" ;;
  esac
}

# Parse and format keybindings into aligned "combo → action" lines.
parse_bindings() {
  local raw_mod submap_name key desc dispatcher arg mod_txt key_combo action

  while IFS="$SEP" read -r raw_mod submap_name key desc dispatcher arg; do
    mod_txt=$(parse_modmask "$raw_mod")
    key_combo="${mod_txt:+$mod_txt + }$key"

    action="$desc"

    # Fallback for the rare case where the description is missing but the
    # dispatcher is a real one (not the opaque Lua handle).
    if [[ -z "$action" || "$action" == "false" ]]; then
      if [[ "$dispatcher" != "__lua" ]]; then
        action="$dispatcher, $arg"
        action="${action/,$/}"
        action=$(sed -r \
          -e 's,~/.local/share/omarchy/bin/,,' \
          -e 's,uwsm app -- ,,' \
          -e 's,uwsm-app -- ,,' \
          -e 's/(^|,)[[:space:]]*exec[[:space:]]*,?//' \
          <<<"$action")
      else
        continue
      fi
    fi

    # Prefix with the submap name when the bind only applies inside one
    # (e.g. "resize", "Multimedia", "Passthrough").
    if [[ -n "$submap_name" ]]; then
      key_combo="[$submap_name] $key_combo"
    fi

    printf "%-35s → %s\n" "$key_combo" "$action"
  done
}

monitor_height=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .height')
menu_height=$((monitor_height * 40 / 100))

dynamic_bindings |
  sort -u |
  parse_bindings |
  #rofi -dmenu -i -p "Shorcuts" -theme-str "window { width: 820px; height: ${menu_height}px; }" -matching fuzzy
  walker --height "$menu_height" --width 800 --dmenu
