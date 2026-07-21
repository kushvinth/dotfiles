#!/bin/bash

export PATH="/run/current-system/sw/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/icons.sh"

update() {
  local DATA
  DATA=$(system_profiler SPAirPortDataType -json 2>/dev/null | \
    jq -r '
      .SPAirPortDataType[0].spairport_airport_interfaces[] |
      select(._name == "en0") |
      if .spairport_status_information == "spairport_status_connected" then
        .spairport_current_network_information._name
      else
        ""
      end
    ' 2>/dev/null)

  local IP_ADDR
  IP_ADDR=$(ipconfig getifaddr en0 2>/dev/null)

  if [ -n "$DATA" ] && [ "$DATA" != "null" ]; then
    ICON="$WIFI_CONNECTED"
    LABEL="$DATA${IP_ADDR:+ ($IP_ADDR)}"
  else
    ICON="$WIFI_DISCONNECTED"
    LABEL="Not Connected"
  fi

  sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
}

click() {
  CURRENT_WIDTH="$(sketchybar --query "$NAME" | jq -r .label.width)"

  if [ "$CURRENT_WIDTH" -eq 0 ]; then
    WIDTH="dynamic"
  else
    WIDTH=0
  fi

  sketchybar --animate sin 20 --set "$NAME" label.width="$WIDTH"
}

case "$SENDER" in
"wifi_change") update ;;
"mouse.clicked") click ;;
esac
