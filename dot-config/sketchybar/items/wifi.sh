#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/icons.sh"

wifi=(
    label.width=dynamic
    icon="$WIFI_DISCONNECTED"
    script="$PLUGIN_DIR/wifi.sh"
    update_freq=10
)

sketchybar --add item wifi right \
    --set wifi "${wifi[@]}" \
    --subscribe wifi wifi_change mouse.clicked

