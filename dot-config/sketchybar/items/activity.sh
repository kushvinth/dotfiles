#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"

activity=(
  icon.drawing=off
  label.drawing=off
  padding.left=1
  padding.right=1
  background.image="$HOME/.config/sketchybar/icon/Waka.png"
  background.image.scale=0.18
  background.color=0x00000000
  script="$PLUGIN_DIR/activity.sh"
  click_script="$PLUGIN_DIR/activity.sh"
)

sketchybar --add item activity right \
           --set activity "${activity[@]}" \
           --subscribe activity mouse.clicked
