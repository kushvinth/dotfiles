#!/bin/bash

#source "$HOME/.config/sketchybar/colors.sh"
#
#COUNT=$(brew outdated | wc -l | tr -d ' ')
#
#COLOR=$RED
#
#case "$COUNT" in
#  [3-5][0-9]) COLOR=$ORANGE
#  ;;
#  [1-2][0-9]) COLOR=$YELLOW
#  ;;
#  [1-9]) COLOR=$WHITE
#  ;;
#  0) COLOR=$GREEN
#     COUNT=􀆅
#  ;;
#esac
#
#sketchybar --set $NAME label=$COUNT icon.color=$COLOR
source "$HOME/.config/sketchybar/colors.sh"
BREW_COUNT=$(brew outdated | wc -l | tr -d ' ') #7
echo "COUNT: $BREW_COUNT" > /tmp/sketchybar_debug.log
echo $(brew outdated | wc -l | tr -d ' ') > /tmp/sketchybar_debugother.log

if [ "$BREW_COUNT" -ge 30 ]; then
    COLOR=$RED
elif [ "$BREW_COUNT" -ge 10 ]; then
    COLOR=$ORANGE
elif [ "$BREW_COUNT" -ge 1 ]; then
    COLOR=$YELLOW
else
    COLOR=$GREEN
    BREW_COUNT=􀆅
fi

sketchybar --set "$NAME" icon.color="$COLOR" label="$BREW_COUNT"
