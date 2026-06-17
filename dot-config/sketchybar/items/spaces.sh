#!/bin/bash

# Barik-style workspace pills (dynamic; see plugins/spaces_barik.sh)
# Reference: barik/Barik/Widgets/Spaces/SpacesWidget.swift

# Remove legacy static yabai.ws.* pool from earlier config
cleanup_legacy_spaces() {
  rm -f "${TMPDIR:-/tmp}/sketchybar-barik-spaces" "${TMPDIR:-/tmp}/sketchybar-barik-spaces.state" \
        "${TMPDIR:-/tmp}/sketchybar-barik-spaces.pool" 2>/dev/null || true
  sketchybar --remove front_app yabai.watcher spaces.separator 2>/dev/null || true
  # Remove all barik space items so reload picks up clean structure
  local query names name safe
  query=$(sketchybar --query '/barik\.ws\..*\.bracket/' 2>/dev/null) || true
  names=$(echo "$query" | jq -r 'if type == "array" then .[].name else .name // empty end' 2>/dev/null) || true
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    safe="${name#barik.ws.}"
    safe="${safe%.bracket}"
    sketchybar --remove "$name" 2>/dev/null || true
    for j in $(seq 1 12); do
      sketchybar --remove "barik.ws.${safe}.app.$j" 2>/dev/null || true
    done
    sketchybar --remove "barik.ws.${safe}.key" "barik.ws.${safe}.title" 2>/dev/null || true
  done <<< "$names"
  for i in $(seq 1 "${SPACES_MAX_SPACES:-9}"); do
    sketchybar --remove "barik.ws.$i.bracket" 2>/dev/null || true
    for j in $(seq 1 12); do
      sketchybar --remove "barik.ws.$i.app.$j" "barik.ws.$i.key" "barik.ws.$i.title" 2>/dev/null || true
    done
  done
  local i j
  for i in $(seq 1 "${SPACES_MAX_SPACES:-9}"); do
    sketchybar --remove "yabai.ws.$i.bracket" "yabai.ws.$i.num" 2>/dev/null || true
    for j in $(seq 1 12); do
      sketchybar --remove "yabai.ws.$i.app.$j" 2>/dev/null || true
    done
  done
}
cleanup_legacy_spaces

export SPACES_SHOW_KEY="${SPACES_SHOW_KEY:-true}"
export SPACES_SHOW_WINDOW_TITLE="${SPACES_SHOW_WINDOW_TITLE:-true}"
export SPACES_SHOW_EMPTY="${SPACES_SHOW_EMPTY:-false}"
export SPACES_TITLE_MAX_LENGTH="${SPACES_TITLE_MAX_LENGTH:-50}"
export SPACES_MAX_SPACES="${SPACES_MAX_SPACES:-9}"

# Barik dark-mode colors (Active / NoActive / Shadow from Assets.xcassets)
export SPACES_ACTIVE_COLOR="${SPACES_ACTIVE_COLOR:-0x66FFFFFF}"
export SPACES_INACTIVE_COLOR="${SPACES_INACTIVE_COLOR:-0x1AFFFFFF}"
export SPACES_SHADOW_COLOR="${SPACES_SHADOW_COLOR:-0x80000000}"
export SPACES_TEXT_COLOR="${SPACES_TEXT_COLOR:-0xE6FFFFFF}"

export SPACES_ANIM_SPACE="${SPACES_ANIM_SPACE:-2}"
export SPACES_ANIM_APP="${SPACES_ANIM_APP:-2}"
export SPACES_ANIM_CURVE="${SPACES_ANIM_CURVE:-circ}"

# Custom events (were previously registered in front_app.sh)
sketchybar --add event window_focus \
           --add event windows_on_spaces

sketchybar --add item spaces.watcher left \
           --set spaces.watcher drawing=off updates=on \
                     script="$PLUGIN_DIR/spaces_barik.sh" \
           --subscribe spaces.watcher space_change window_focus \
                         windows_on_spaces system_woke
