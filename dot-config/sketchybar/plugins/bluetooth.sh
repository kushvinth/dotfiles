#!/bin/bash

export PATH="/run/current-system/sw/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

update() {
  local DATA
  DATA=$(system_profiler SPBluetoothDataType -json 2>/dev/null | \
    /usr/bin/jq -r '
      .SPBluetoothDataType[0] |
      if .controller_properties.controller_state == "attrib_on" then
        if has("device_connected") then
          "connected " + ([.device_connected[] | keys[0]] | length | tostring)
        else
          "on"
        end
      else
        "off"
      end
    ' 2>/dev/null)

  case "$DATA" in
    connected*)
      local COUNT="${DATA#connected }"
      sketchybar --set "$NAME" icon="$BLUETOOTH_CONNECTED" icon.color="$BLUE" \
        label="$COUNT" label.drawing=on
      ;;
    on)
      sketchybar --set "$NAME" icon="$BLUETOOTH_ON" icon.color="$WHITE" label.drawing=off
      ;;
    off|*)
      sketchybar --set "$NAME" icon="$BLUETOOTH_OFF" icon.color="$GREY" label.drawing=off
      ;;
  esac
}

click() {
  local BLUEUTIL="/run/current-system/sw/bin/blueutil"
  if [ -x "$BLUEUTIL" ]; then
    local CURRENT_STATE
    CURRENT_STATE=$("$BLUEUTIL" -p 2>/dev/null)
    if [ "$CURRENT_STATE" = "0" ]; then
      "$BLUEUTIL" -p 1
    else
      "$BLUEUTIL" -p 0
    fi
    update
  else
    open "x-apple.systempreferences:com.apple.BluetoothSettings"
  fi
}

case "$SENDER" in
  "mouse.clicked") click ;;
  *) update ;;
esac
