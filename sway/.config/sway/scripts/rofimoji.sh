#!/usr/bin/env bash
ROFIPID=$(pgrep rofimoji)
if [[ -n $ROFIPID ]];then
    kill "$ROFIPID"
fi

rofimoji --selector-args "-monitor ${MONITOR}" \
    --selector rofi \
    --clipboarder wl-copy \
    --skin-tone neutral \
