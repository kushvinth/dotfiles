#!/bin/bash
# inspo: https://github.com/kejadlen/dotfiles/blob/7eac34262edfab1b6774c158de2f83c0b26a363c/.config/sketchybar/plugins/tailscale.sh
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

LOCK_ICON=􀎡
UNLOCK_ICON=􀎥

# Toggle tailscale on click
if [ "$SENDER" = "mouse.clicked" ]; then
	if tailscale status --self &>/dev/null; then
		# Currently connected, disconnecting - show unlock animation
		sketchybar --set "$NAME" background.image.scale=0 icon.drawing=on icon="$UNLOCK_ICON" icon.color=$RED
		sketchybar --animate sin 15 --set "$NAME" icon.color=$GREY
		tailscale down
		sleep 1
		sketchybar --set "$NAME" icon.drawing=off background.image.scale=0.03
	else
		# Currently disconnected, connecting - show lock animation
		tailscale up
		sleep 0.5
		sketchybar --set "$NAME" background.image.scale=0 icon.drawing=on icon="$LOCK_ICON" icon.color=$GREY
		sketchybar --animate sin 15 --set "$NAME" icon.color=$GREEN
		sleep 1
		sketchybar --set "$NAME" icon.drawing=off background.image.scale=0.03
	fi
fi

sketchybar --set "$NAME"