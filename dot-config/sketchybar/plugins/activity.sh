#!/bin/bash

DEBUG_LOG="$HOME/.config/sketchybar/debug_activity.log"
CACHE_FILE="/tmp/sketchybar-activity.time"
CACHE_TTL_SECONDS=120

popup() {
  sketchybar --set "$NAME" popup.drawing=$1
}

update() {
  mkdir -p "$(dirname "$CACHE_FILE")"

  now=$(date +%s)
  cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  cache_age=$((now - cache_mtime))

  if [ -f "$CACHE_FILE" ] && [ "$cache_age" -lt "$CACHE_TTL_SECONDS" ]; then
    cached_value=$(cat "$CACHE_FILE" 2>/dev/null)
    [ -z "$cached_value" ] && cached_value="N/A"
    sketchybar --set activity.time label="$cached_value"
    return
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    if [ -f "$CACHE_FILE" ]; then
      cached_value=$(cat "$CACHE_FILE" 2>/dev/null)
      [ -z "$cached_value" ] && cached_value="N/A"
      sketchybar --set activity.time label="$cached_value"
    else
      sketchybar --set activity.time label="N/A"
    fi
    return
  fi

  api_url="${WAKAPI_URL:-https://wakapi.kushvinth.com}"
  api_key="${WAKAPI_API_KEY:-}"

  if [ -z "$api_key" ]; then
    if [ -f "$CACHE_FILE" ]; then
      time_data=$(cat "$CACHE_FILE" 2>/dev/null)
      [ -z "$time_data" ] && time_data="N/A"
    else
      time_data="N/A"
    fi
    sketchybar --set activity.time label="$time_data"
    return
  fi
  time_data=$(curl -fsS "${api_url}/api/v1/users/current/stats/today?api_key=${api_key}" 2>/dev/null | jq -r '.data.human_readable_total // empty' 2>/dev/null)

  if [ -n "$time_data" ]; then
    printf '%s' "$time_data" > "$CACHE_FILE"
  elif [ -f "$CACHE_FILE" ]; then
    time_data=$(cat "$CACHE_FILE" 2>/dev/null)
  else
    time_data="N/A"
  fi

  sketchybar --set activity.time label="$time_data"
}

click() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - click called" >> "$DEBUG_LOG"
  open "https://wakapi.kushvinth.com/"
}

case "$SENDER" in
  "routine" | "forced")
    update
    ;;
  "mouse.entered")
    update
    popup on
    ;;
  "mouse.exited" | "mouse.exited.global")
    popup off
    ;;
  "mouse.clicked")
    click
    ;;
esac
