if pgrep -x spotify &>/dev/null; then
    (spicetify watch -s -n 2>&1 | sed "/Reloaded Spotify/q") &
    disown
fi
