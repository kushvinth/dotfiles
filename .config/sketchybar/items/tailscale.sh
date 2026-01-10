#!/bin/bash

tailscale=(
    icon=􀙇
    icon.color=$GREEN
    label.drawing=off
    update_freq=10
    script="$PLUGIN_DIR/tailscale.sh"
    click_script="$PLUGIN_DIR/tailscale.sh"
)

sketchybar --add item tailscale right \
           --set tailscale "${tailscale[@]}" \
           --subscribe tailscale mouse.clicked system_woke
