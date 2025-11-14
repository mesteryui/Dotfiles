#!/bin/bash 

have() { command -v "$1" >/dev/null 2>&1; }
PLAYERCTL_TIMEOUT=2

run_with_timeout() {
  timeout "$PLAYERCTL_TIMEOUT" "$@" 2>/dev/null || true
}
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
playerctl_control() {
  local player

  # Tomar el primer activo según prioridad
  player=$(get_active_players | head -n1)

  # Si no hay ninguno, salir con error
  [[ -z "$player" ]] && {
    echo "No se encontró ningún reproductor MPRIS activo" >&2
    return 1
  }

  # Ejecutar el comando sobre el player elegido
  playerctl -p "$player" "$@"
}

playerctl_control "$@"
