#!/bin/bash
#  _   _                  _     _ _      
# | | | |_   _ _ __  _ __(_) __| | | ___ 
# | |_| | | | | '_ \| '__| |/ _` | |/ _ \
# |  _  | |_| | |_) | |  | | (_| | |  __/
# |_| |_|\__, | .__/|_|  |_|\__,_|_|\___|
#        |___/|_|                        
# 

SERVICE="hypridle"
if [[ "$1" == "status" ]]; then
    sleep 1
    if systemctl is-active --user --quiet "$SERVICE" >/dev/null ;then
    	echo '{"text": "  On", "tooltip": "Hypridle esta activado"}'       
    else
        echo '{"text": "  Off", "tooltip": "Hypridle esta desactivado"}'
    fi
fi
if [[ "$1" == "toggle" ]]; then
    if systemctl is-active --user --quiet "$SERVICE" >/dev/null ;then
        killall hypridle
    else
        hypridle
    fi
fi
