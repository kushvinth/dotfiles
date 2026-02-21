#!/bin/bash
unset ZDOTDIR
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

# Get outdated count using wc -l (simpler and more reliable)
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
# BREW_COUNT=$(brew outdated --quiet 2>/dev/null | wc -l)
BREW_COUNT=$(brew outdated)
say "$BREW_COUNT"
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
