#!/usr/bin/env fish
set -l ROFIPID (pgrep rofimoji)
if test -f $ROFIPID
    kill "$ROFIPID"
end

rofimoji \
    --selector rofi \
    --skin-tone neutral \

# --clipboarder wl-clipboard 
