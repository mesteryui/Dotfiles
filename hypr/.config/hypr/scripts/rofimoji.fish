#!/usr/bin/env fish
set -l ROFIPID (pgrep rofimoji)
if test -f $ROFIPID
    kill "$ROFIPID"
end

rofimoji --selector-args "-monitor $MONITOR" \
    --selector rofi \
    --clipboarder wl-copy \
    --skin-tone neutral \
