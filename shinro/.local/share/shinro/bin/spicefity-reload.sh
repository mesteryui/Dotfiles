#!/usr/bin/env bash
set -euo pipefail

if ! command -v pgrep &>/dev/null || ! command -v spicetify &>/dev/null; then
    exit 0
fi

if pgrep -x spotify &>/dev/null; then
    (spicetify watch -s -n 2>&1 | sed "/Reloaded Spotify/q") &
    disown
fi
