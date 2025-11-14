#!/usr/bin/env bash
# hyprlock-music.sh - Universal music player integration for Hyprlock
# Displays current track info, album art, and playback controls
# Dependencies: playerctl (required), curl (optional, for remote art), ImageMagick (optional, for cropping)

set -Eeuo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Album art cache settings
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock-art"
SQUARE_SIZE=1024
mkdir -p "$CACHE_DIR"

# Progress bar appearance
BAR_LENGTH=16
BAR_CHAR="━"
BAR_HANDLE="⦿"
COLOR_PLAYED="ffffff99"
COLOR_REMAINING="ffffff30"

# Timeouts and retries
PLAYERCTL_TIMEOUT=2
CURL_TIMEOUT=5

# ============================================================================
# Helper Functions
# ============================================================================

# Check if command exists
have() { command -v "$1" >/dev/null 2>&1; }

# Execute command with timeout
run_with_timeout() {
  timeout "$PLAYERCTL_TIMEOUT" "$@" 2>/dev/null || true
}

# ============================================================================
# Player Detection
# ============================================================================

# Get all active players sorted by status priority
get_active_players() {
  if ! have playerctl; then
    return 1
  fi

  # Get all players with their status
  local playing_players=()
  local paused_players=()
  local other_players=()

  while IFS= read -r player; do
    [[ -z "$player" ]] && continue
    
    local status
    status=$(run_with_timeout playerctl -p "$player" status) || continue
    
    case "${status,,}" in
      playing)
        playing_players+=("$player")
        ;;
      paused)
        paused_players+=("$player")
        ;;
      *)
        other_players+=("$player")
        ;;
    esac
  done < <(playerctl -l 2>/dev/null || true)

  # Return players in priority order: playing > paused > others
  printf '%s\n' "${playing_players[@]}" "${paused_players[@]}" "${other_players[@]}" 2>/dev/null || true
}

# Get the best available player
select_player() {
  local first_player
  first_player=$(get_active_players | head -n1)
  printf '%s' "$first_player"
}

# ============================================================================
# Metadata Functions
# ============================================================================

# Get metadata with multiple fallback strategies
get_metadata() {
  local key="$1"
  local player
  player="$(select_player)"

  [[ -z "$player" ]] && return 1

  local value
  value=$(run_with_timeout playerctl -p "$player" metadata "$key")
  
  # Fallback: try without key prefix if it's an mpris key
  if [[ -z "$value" && "$key" == mpris:* ]]; then
    local alt_key="${key#mpris:}"
    value=$(run_with_timeout playerctl -p "$player" metadata "$alt_key")
  fi

  # Fallback: try with xesam prefix
  if [[ -z "$value" && "$key" != xesam:* ]]; then
    value=$(run_with_timeout playerctl -p "$player" metadata "xesam:$key")
  fi

  printf '%s' "$value"
}

# Get metadata with format string
get_metadata_formatted() {
  local format="$1"
  local player
  player="$(select_player)"

  [[ -z "$player" ]] && return 1

  run_with_timeout playerctl -p "$player" metadata --format "$format"
}

# Get player status (Playing/Paused/Stopped)
get_status() {
  local player
  player="$(select_player)"

  [[ -z "$player" ]] && return 1

  run_with_timeout playerctl -p "$player" status
}

# Truncate string with ellipsis if too long
trim_string() {
  local str="${1:-}"
  local max_len="${2:-30}"
  
  # Handle empty strings
  [[ -z "$str" ]] && return 0
  
  local str_len=${#str}

  if ((str_len <= max_len)); then
    printf '%s' "$str"
  else
    printf '%s…' "${str:0:max_len}"
  fi
}

# ============================================================================
# Time Conversion Functions
# ============================================================================

# Convert various time formats to seconds
parse_time_to_seconds() {
  local time="$1"
  
  # Empty or invalid
  [[ -z "$time" ]] && echo "0" && return
  
  # Remove any non-numeric characters except dots
  time=$(echo "$time" | tr -cd '0-9.')
  
  [[ -z "$time" ]] && echo "0" && return

  # Already in seconds (playerctl position output)
  if [[ "$time" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    printf '%.0f' "$time" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Convert microseconds to seconds
microseconds_to_seconds() {
  local us="$1"
  [[ "$us" =~ ^[0-9]+$ ]] || { echo "0"; return; }
  echo $((us / 1000000))
}

# Format seconds to mm:ss
seconds_to_mmss() {
  local seconds="$1"
  [[ "$seconds" =~ ^[0-9]+$ ]] || { echo "0:00"; return; }
  printf '%d:%02d' $((seconds / 60)) $((seconds % 60))
}

# Get track length in seconds (with multiple fallbacks)
get_track_length_seconds() {
  local player
  player="$(select_player)"
  [[ -z "$player" ]] && echo "0" && return

  # Try mpris:length (microseconds)
  local length_us
  length_us=$(get_metadata 'mpris:length' 2>/dev/null) || true
  
  if [[ -n "$length_us" && "$length_us" =~ ^[0-9]+$ && "$length_us" -gt 0 ]]; then
    microseconds_to_seconds "$length_us"
    return
  fi

  # Fallback: try length metadata without prefix
  length_us=$(get_metadata 'length' 2>/dev/null) || true
  if [[ -n "$length_us" && "$length_us" =~ ^[0-9]+$ && "$length_us" -gt 0 ]]; then
    microseconds_to_seconds "$length_us"
    return
  fi

  # Default
  echo "0"
}

# Get track length in mm:ss
get_track_length() {
  local seconds
  seconds=$(get_track_length_seconds)
  seconds_to_mmss "$seconds"
}

# Get current position in seconds
get_current_position_seconds() {
  local player
  player="$(select_player)"
  [[ -z "$player" ]] && echo "0" && return

  local pos
  pos=$(run_with_timeout playerctl -p "$player" position 2>/dev/null) || true
  parse_time_to_seconds "$pos"
}

# Get current position in mm:ss
get_current_position() {
  local seconds
  seconds=$(get_current_position_seconds)
  seconds_to_mmss "$seconds"
}

# ============================================================================
# Progress Functions
# ============================================================================

# Calculate progress percentage (0-100)
calculate_progress_percent() {
  local player
  player="$(select_player)"
  [[ -z "$player" ]] && echo "0" && return

  local pos_sec length_sec
  pos_sec=$(get_current_position_seconds)
  length_sec=$(get_track_length_seconds)

  if [[ "$length_sec" -gt 0 && "$pos_sec" -ge 0 ]]; then
    local percent=$((pos_sec * 100 / length_sec))
    # Cap at 100
    [[ $percent -gt 100 ]] && percent=100
    printf '%d' "$percent"
  else
    printf '0'
  fi
}

# Generate progress bar with Pango markup
generate_progress_bar() {
  local percent
  percent=$(calculate_progress_percent)

  local current_status
  current_status=$(get_status 2>/dev/null) || true

  # Return empty bar if nothing is playing
  if [[ -z "$current_status" || "$current_status" == "Stopped" ]]; then
    local empty_bar=""
    for ((i = 0; i < BAR_LENGTH; i++)); do
      empty_bar+="$BAR_CHAR"
    done
    printf '<span foreground="#%s">%s</span>' "$COLOR_REMAINING" "$empty_bar"
    return
  fi

  # Treat 95%+ as 100% to handle players switching tracks early
  [[ $percent -ge 95 ]] && percent=100

  # Calculate filled segments
  local progress=$((percent * BAR_LENGTH / 100))
  [[ $progress -gt $BAR_LENGTH ]] && progress=$BAR_LENGTH
  [[ $progress -lt 0 ]] && progress=0

  # Build bar segments
  local bar_played=""
  local bar_remaining=""

  for ((i = 0; i < progress; i++)); do
    bar_played+="$BAR_CHAR"
  done

  for ((i = progress; i < BAR_LENGTH; i++)); do
    bar_remaining+="$BAR_CHAR"
  done

  # Generate Pango markup based on position
  if [[ $progress -eq $BAR_LENGTH ]]; then
    printf '<span foreground="#%s">%s</span><span foreground="#ffffff99">%s</span>' \
      "$COLOR_PLAYED" "$bar_played" "$BAR_HANDLE"
  elif [[ $progress -eq 0 ]]; then
    printf '<span foreground="#ffffff99">%s</span><span foreground="#%s">%s</span>' \
      "$BAR_HANDLE" "$COLOR_REMAINING" "${bar_remaining}"
  else
    printf '<span foreground="#%s">%s</span><span foreground="#ffffff99">%s</span><span foreground="#%s">%s</span>' \
      "$COLOR_PLAYED" "$bar_played" "$BAR_HANDLE" "$COLOR_REMAINING" "$bar_remaining"
  fi
}

# ============================================================================
# Album Art Functions
# ============================================================================

# Clean old cache files (older than 7 days)
clean_old_cache() {
  find "$CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null || true
}

# Download remote URL to cache
download_to_cache() {
  local url="$1"
  
  have curl || return 1
  
  # Generate safe filename from URL hash
  local filename
  filename="$(printf '%s' "$url" | sha256sum | awk '{print $1}').img"
  local output="$CACHE_DIR/$filename"

  # Return cached file if it exists and is valid
  if [[ -s "$output" ]]; then
    printf '%s' "$output"
    return 0
  fi

  # Download with timeout and error handling
  if curl -fsSL --max-time "$CURL_TIMEOUT" --retry 2 "$url" -o "$output" 2>/dev/null; then
    # Verify downloaded file is not empty and is an image
    if [[ -s "$output" ]]; then
      if have file && file "$output" 2>/dev/null | grep -qiE 'image|jpeg|png|jpg'; then
        printf '%s' "$output"
        return 0
      elif [[ ! $(command -v file) ]]; then
        # If file command doesn't exist, trust the download
        printf '%s' "$output"
        return 0
      fi
    fi
    rm -f "$output" 2>/dev/null || true
  fi
  
  return 1
}

# Create square-cropped album art
create_square_cover() {
  local input="$1"
  
  [[ ! -s "$input" ]] && return 1
  
  local basename
  basename="$(basename "$input")"
  local output="$CACHE_DIR/${basename%.*}_sq_${SQUARE_SIZE}.jpg"

  # Return cached version if it exists and is newer
  if [[ -s "$output" && "$output" -nt "$input" ]]; then
    printf '%s' "$output"
    return 0
  fi

  # Create square crop with ImageMagick
  if have convert; then
    if convert "$input" -auto-orient -gravity center \
      -thumbnail "${SQUARE_SIZE}x${SQUARE_SIZE}^" \
      -extent "${SQUARE_SIZE}x${SQUARE_SIZE}" \
      -quality 90 "$output" 2>/dev/null; then
      printf '%s' "$output"
      return 0
    fi
  fi

  # Fallback to original if ImageMagick unavailable or failed
  printf '%s' "$input"
  return 0
}

# Get path to square album art
get_album_art_path() {
  # Clean old cache periodically (in background)
  (clean_old_cache &) 2>/dev/null || true

  local url
  url=$(get_metadata 'mpris:artUrl' 2>/dev/null) || url=$(get_metadata 'artUrl' 2>/dev/null) || true

  [[ -z "$url" ]] && return 1

  local local_path=""

  case "$url" in
  file://*)
    local_path="${url#file://}"
    # Decode URL encoding
    local_path=$(printf '%b' "${local_path//%/\\x}" 2>/dev/null) || local_path="${url#file://}"
    ;;
  http://* | https://*)
    local_path=$(download_to_cache "$url") || return 1
    ;;
  /*)
    # Already a local path
    local_path="$url"
    ;;
  *)
    return 1
    ;;
  esac

  [[ -n "$local_path" && -s "$local_path" ]] || return 1

  create_square_cover "$local_path"
}

# ============================================================================
# Display Functions
# ============================================================================

# Get player status icon
get_status_icon() {
  local status
  status=$(get_status 2>/dev/null) || true
  
  case "${status,,}" in
  playing)
    printf '󰏤'
    ;;
  paused)
    printf '󰐊'
    ;;
  stopped | *)
    printf '󰓛'
    ;;
  esac
}

# Detect player type from player name
detect_player_type() {
  local player="$1"
  local player_lower="${player,,}"
  
  case "$player_lower" in
    *spotify*)     echo "spotify" ;;
    *firefox*)     echo "firefox" ;;
    *chromium*)    echo "chromium" ;;
    *brave*)       echo "brave" ;;
    *chrome*)      echo "chrome" ;;
    *mpv*)         echo "mpv" ;;
    *vlc*)         echo "vlc" ;;
    *rhythmbox*)   echo "rhythmbox" ;;
    *clementine*)  echo "clementine" ;;
    *audacious*)   echo "audacious" ;;
    *strawberry*)  echo "strawberry" ;;
    *elisa*)       echo "elisa" ;;
    *amarok*)      echo "amarok" ;;
    *quodlibet*)   echo "quodlibet" ;;
    *deadbeef*)    echo "deadbeef" ;;
    *cmus*)        echo "cmus" ;;
    *mopidy*)      echo "mopidy" ;;
    *kodi*)        echo "kodi" ;;
    *plex*)        echo "plex" ;;
    *jellyfin*)    echo "jellyfin" ;;
    *)             echo "unknown" ;;
  esac
}

# Get formatted player name with icon
get_player_display() {
  local player
  player=$(select_player) || { echo "No Player"; return 0; }

  local player_type
  player_type=$(detect_player_type "$player")

  case "$player_type" in
    spotify)     printf '󰓇  Spotify' ;;
    firefox)     printf '󰈹  Firefox' ;;
    chromium)    printf '󰊯  Chromium' ;;
    brave)       printf '󰞀  Brave' ;;
    chrome)      printf '󰊯  Chrome' ;;
    mpv)         printf '󰕼  mpv' ;;
    vlc)         printf '󰕼  VLC' ;;
    rhythmbox)   printf '󰓃  Rhythmbox' ;;
    clementine)  printf '󰓃  Clementine' ;;
    audacious)   printf '󰓃  Audacious' ;;
    strawberry)  printf '󰓃  Strawberry' ;;
    elisa)       printf '󰝚  Elisa' ;;
    amarok)      printf '󰓃  Amarok' ;;
    quodlibet)   printf '󰓃  Quod Libet' ;;
    deadbeef)    printf '󰓃  DeaDBeeF' ;;
    cmus)        printf '󰓃  cmus' ;;
    mopidy)      printf '󰓃  Mopidy' ;;
    kodi)        printf '󰕧  Kodi' ;;
    plex)        printf '󰚺  Plex' ;;
    jellyfin)    printf '󰚺  Jellyfin' ;;
    *)
      # Extract app name from player string
      local display_name
      display_name=$(printf '%s' "$player" | sed 's/\.[0-9]*$//' | sed 's/^.*\.//')
      printf '󰝚  %s' "${display_name^}"
      ;;
  esac
}

# Get title with multiple fallbacks
get_title() {
  local title
  title=$(get_metadata 'xesam:title' 2>/dev/null) || \
  title=$(get_metadata 'title' 2>/dev/null) || \
  title=$(get_metadata_formatted '{{ title }}' 2>/dev/null) || \
  title=""

  if [[ -z "$title" ]]; then
    echo "Nothing Playing"
  else
    trim_string "$title" 29
  fi
}

# Get artist with multiple fallbacks
get_artist() {
  local artist
  artist=$(get_metadata 'xesam:artist' 2>/dev/null) || \
  artist=$(get_metadata 'artist' 2>/dev/null) || \
  artist=$(get_metadata_formatted '{{ artist }}' 2>/dev/null) || \
  artist=""

  if [[ -n "$artist" ]]; then
    trim_string "$artist" 26
  else
    echo ""
  fi
}

# ============================================================================
# Command-Line Interface
# ============================================================================

case "${1:-}" in
--title)
  get_title
  ;;

--artist)
  get_artist
  ;;

--status)
  get_status_icon
  ;;

--length)
  get_track_length
  ;;

--position)
  get_current_position
  ;;

--progress)
  calculate_progress_percent
  ;;

--progress-bar)
  generate_progress_bar
  ;;

--art)
  get_album_art_path 2>/dev/null || echo ""
  ;;

--player)
  get_player_display
  ;;

--list-players)
  get_active_players
  ;;

--help | *)
  cat <<EOF
Usage: $(basename "$0") [OPTION]

Universal music player information for Hyprlock.

Options:
  --title         Display song title (truncated to 29 chars)
  --artist        Display artist name (truncated to 26 chars)
  --status        Display play/pause/stop icon
  --length        Display total track length (mm:ss)
  --position      Display current position (mm:ss)
  --progress      Display progress percentage (0-100)
  --progress-bar  Display colored progress bar with Pango markup
  --art           Display path to square-cropped album art
  --player        Display player name with icon
  --list-players  List all active players in priority order
  --help          Show this help message

Features:
  - Automatic player detection (no hardcoded list needed)
  - Prioritizes playing over paused players
  - Multiple metadata fallbacks for compatibility
  - Robust error handling and timeouts
  - Efficient caching system for album art
  - Supports 15+ media players automatically

Examples:
  $(basename "$0") --title
  $(basename "$0") --progress-bar
  $(basename "$0") --list-players

EOF
  exit 0
  ;;
esac
