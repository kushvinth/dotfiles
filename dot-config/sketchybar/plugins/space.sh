#!/bin/bash

update() {
  WIDTH="dynamic"
  if [ "$SELECTED" = "true" ]; then
    WIDTH="0"
  fi

  # Get the app running in this space
  SPACE_APP=$(yabai -m query --windows --space $SID | jq -r '.[0].app' 2>/dev/null)
  
  if [ -n "$SPACE_APP" ] && [ "$SPACE_APP" != "null" ]; then
    sketchybar --animate tanh 20 \
               --set $NAME icon.highlight=$SELECTED \
                           label.width=$WIDTH \
                           icon.background.image="app.$SPACE_APP" \
                           icon.background.image.scale=0.8
  else
    sketchybar --animate tanh 20 \
               --set $NAME icon.highlight=$SELECTED \
                           label.width=$WIDTH \
                           icon.background.image="" \
                           icon.background.image.scale=0.8
  fi
}

mouse_clicked() {
  if [ "$BUTTON" = "right" ]; then
    yabai -m space --destroy $SID
    sketchybar --trigger space_change --trigger windows_on_spaces
  else
    yabai -m space --focus $SID 2>/dev/null
  fi
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  *) update
  ;;
esac
