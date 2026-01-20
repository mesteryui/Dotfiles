#!/usr/bin/env bash
# hyprlock-music.sh - Simple music player integration for Hyprlock
# Shows only playback status icon and track title

set -Eeuo pipefail

# Check if playerctl is available
if ! command -v playerctl &> /dev/null; then
  exit 1
fi

PLAYERCTL_TIMEOUT=2

# Get the first active player
get_player() {
  playerctl -l 2>/dev/null | head -n1
}

# Get player status
get_status() {
  local player
  player=$(get_player)
  
  if [[ -z "$player" ]]; then
    return 1
  fi
  
  timeout "$PLAYERCTL_TIMEOUT" playerctl -p "$player" status 2>/dev/null || return 1
}

# Get status icon based on playback state
get_status_icon() {
  local status
  status=$(get_status 2>/dev/null) || status="paused"
  
  case "${status,,}" in
    playing)
      printf '󰏤'
      ;;
    paused)
      printf '󰐊'
      ;;
    *)
      printf '󰓛'
      ;;
  esac
}

# Get track title
get_title() {
  local player
  player=$(get_player)
  
  if [[ -z "$player" ]]; then
    echo "No Player"
    return
  fi
  
  local title
  title=$(timeout "$PLAYERCTL_TIMEOUT" playerctl -p "$player" metadata xesam:title 2>/dev/null) || title=""
  
  if [[ -z "$title" ]]; then
    echo "Nothing Playing"
  else
    # Truncate to 30 characters
    if [[ ${#title} -gt 30 ]]; then
      echo "${title:0:30}…"
    else
      echo "$title"
    fi
  fi
}

# Main
case "${1:-}" in
  --status)
    get_status_icon
    ;;
  --title)
    get_title
    ;;
  --help)
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Simple music player display for Hyprlock.

Options:
  --status  Show playback status icon (play/pause/stop)
  --title   Show current track title
  --help    Show this help message

Examples:
  $(basename "$0") --status
  $(basename "$0") --title
EOF
    exit 0
    ;;
  *)
    echo "Usage: $(basename "$0") [--status|--title|--help]"
    exit 1
    ;;
esac
