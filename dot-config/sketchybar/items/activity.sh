#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"

activity=(
  icon.drawing=off
  label.drawing=off
  padding.left=1
  padding.right=10
  background.image="$HOME/.config/sketchybar/icon/Waka.png"
  background.image.scale=0.18
  background.color=0x00000000
  update_freq=10
  popup.align=right
  script="$PLUGIN_DIR/activity.sh"
  click_script="$PLUGIN_DIR/activity.sh"
)

sketchybar --add item activity right \
           --set activity "${activity[@]}" \
           --subscribe activity mouse.clicked mouse.entered mouse.exited mouse.exited.global routine \
           \
           --add item activity.time popup.activity \
           --set activity.time label="" label.font="SF Pro:Regular:13.0" label.color=$WHITE padding_left=10 padding_right=10
