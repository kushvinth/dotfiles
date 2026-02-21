#!/bin/bash

tailscale=(
    icon.drawing=off
    label.drawing=off
    background.image="$HOME/.config/sketchybar/icon/tailscale.png"
    background.image.scale=0.03
    background.color=0x00000000
    # padding_right=5
    padding_left=5
    update_freq=10
    script="$PLUGIN_DIR/tailscale.sh"
    click_script="$PLUGIN_DIR/tailscale.sh"
)

sketchybar --add item tailscale right \
           --set tailscale "${tailscale[@]}" \
           --subscribe tailscale mouse.clicked system_woke