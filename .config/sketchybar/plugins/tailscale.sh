#!/bin/bash
# inspo: https://github.com/kejadlen/dotfiles/blob/7eac34262edfab1b6774c158de2f83c0b26a363c/.config/sketchybar/plugins/tailscale.sh
source "$CONFIG_DIR/colors.sh"

# Toggle tailscale on click
if [ "$SENDER" = "mouse.clicked" ]; then
	if tailscale status --self &>/dev/null; then
		tailscale down 
	else
		tailscale up
	fi
	sleep 0.5  # Wait for status to update
fi

# Update icon based on status
if tailscale status --self &>/dev/null; then
	ICON=􀎡
	ICON_COLOR=$GREEN
else
	ICON=􀎥
	ICON_COLOR=$GREY
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR"
