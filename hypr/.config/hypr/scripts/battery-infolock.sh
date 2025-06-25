#!/bin/bash

BAT="BATT" # El nombre de la bateria mejor en una variable para facilitar el tema de bueno no tener que poner el nombre de la bateria, cada maldita vez

# Get the current battery percentage
battery_percentage=$(cat "/sys/class/power_supply/$BAT/capacity")

# Get the battery status (Charging or Discharging)
battery_status=$(cat "/sys/class/power_supply/$BAT/status")

# Define the battery icons for each 10% segment
# battery_icons=("󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹")

# # Define the charging icon
# charging_icon="󰂄"
battery_icons=("" "" "" "" "" "" "" "" "" "")
charging_icon=""

# Calculate the index for the icon array
icon_index=$((battery_percentage / 10))

# Get the corresponding icon
battery_icon=${battery_icons[icon_index]}
if [ $battery_percentage -eq 100 ]; then 
    battery_icon=""
fi
# Check if the battery is charging
if [ "$battery_status" = "Charging" ]; then
	battery_icon="$charging_icon"
fi

# Output the battery percentage and icon
#printf "%s%% %s\n" "$battery_percentage" "$battery_icon"
echo "$battery_percentage% $battery_icon"
