#!/usr/bin/env bash

killall -9 waybar
waybar -s ~/.config/waybar/style-hypr.css -c ~/.config/waybar/config-hypr.jsonc &
