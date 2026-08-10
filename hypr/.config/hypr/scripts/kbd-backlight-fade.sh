#!/usr/bin/env bash
# Fade the keyboard backlight in (fast) or out (slow).
# Usage: kbd-backlight-fade.sh in|out

DEVICE="kbd_backlight"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/kbd_backlight_on_value"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/kbd_backlight_fade.pid"
MAX=$(brightnessctl -d "$DEVICE" max)

# Cancel whatever fade is currently in flight so overlapping in/out
# calls can't race each other and leave the brightness stuck mid-fade.
if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE")"
    if [ -n "$old_pid" ] && [ "$old_pid" != "$$" ] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null
    fi
fi
echo "$$" > "$PID_FILE"

fade() {
    local from="$1" to="$2" duration_ms="$3" steps="$4"
    local delay
    delay=$(awk -v d="$duration_ms" -v s="$steps" 'BEGIN { printf "%.3f", d / 1000 / s }')
    for i in $(seq 1 "$steps"); do
        local val
        val=$(awk -v f="$from" -v t="$to" -v i="$i" -v s="$steps" 'BEGIN { printf "%d", f + (t - f) * i / s }')
        brightnessctl -d "$DEVICE" set "$val" >/dev/null
        sleep "$delay"
    done
}

current=$(brightnessctl -d "$DEVICE" get)

case "$1" in
    in)
        target="$MAX"
        [ -f "$STATE_FILE" ] && target="$(cat "$STATE_FILE")"
        fade "$current" "$target" 150 6
        ;;
    out)
        [ "$current" -gt 0 ] && echo "$current" > "$STATE_FILE"
        fade "$current" 0 1200 15
        ;;
esac
