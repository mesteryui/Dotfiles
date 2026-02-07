#!/usr/bin/env bash
STATUS=$(hyprctl getoption plugin:hyprbars:enabled | grep -Po '(?<=int: )[^ ]+')

if [ "$STATUS" -eq 1 ]; then
    hyprctl keyword plugin:hyprbars:enabled 0
else
    hyprctl keyword plugin:hyprbars:enabled 1
fi
