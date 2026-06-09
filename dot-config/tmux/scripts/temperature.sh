#!/usr/bin/env bash
set -uo pipefail

CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-temperature.cache"
CACHE_TTL=10

read_cache() {
  [[ -f "$CACHE_FILE" ]] || return 1
  local now mtime age
  now=$(date +%s)
  if [[ "$(uname -s)" == "Darwin" ]]; then
    mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  else
    mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  fi
  age=$((now - mtime))
  [[ "$age" -lt "$CACHE_TTL" ]] || return 1
  cat "$CACHE_FILE"
}

write_cache() {
  printf '%s' "$1" > "$CACHE_FILE"
}

emit_json() {
  local temp="$1"
  local class="normal"

  if (( temp >= 80 )); then
    class="critical"
  elif (( temp >= 70 )); then
    class="warning"
  fi

  jq -cn \
    --arg text "$temp" \
    --arg tooltip "CPU: ${temp}°C" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

emit_unavailable() {
  jq -cn '{text: "—", tooltip: "Temperature unavailable", class: "unavailable"}'
}

macos_macmon_temp() {
  command -v macmon >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1

  macmon pipe -s 1 2>/dev/null \
    | jq -r '(.temp.cpu_temp_avg // empty) | if . then (.*1 | round | tostring) else empty end'
}

macos_osx_cpu_temp() {
  command -v osx-cpu-temp >/dev/null 2>&1 || return 1

  local combined temp
  combined=$(osx-cpu-temp 2>&1) || true
  if [[ "$combined" == *Error:* ]]; then
    return 1
  fi

  temp=$(printf '%s\n' "$combined" | grep -oE '[0-9]+\.[0-9]+' | head -1)
  [[ -n "$temp" && "$temp" != "0.0" ]] || return 1

  awk -v t="$temp" 'BEGIN { printf "%d", t + 0.5 }'
}

macos_istats_temp() {
  command -v istats >/dev/null 2>&1 || return 1
  istats cpu temp 2>/dev/null | awk '{ printf "%d", $4 + 0.5 }'
}

linux_sensors_temp() {
  command -v sensors >/dev/null 2>&1 || return 1
  sensors 2>/dev/null \
    | awk -F'[:+°]' '/Package id 0|Tctl|Tdie|Core 0/ { printf "%d", $2 + 0.5; exit }'
}

linux_sysfs_temp() {
  local zone="/sys/class/thermal/thermal_zone0/temp"
  [[ -r "$zone" ]] || return 1
  awk '{ printf "%d", $1 / 1000 + 0.5 }' "$zone"
}

read_temp() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    macos_macmon_temp || macos_osx_cpu_temp || macos_istats_temp
  else
    linux_sensors_temp || linux_sysfs_temp
  fi
}

cached=$(read_cache 2>/dev/null || true)
if [[ -n "$cached" ]]; then
  printf '%s' "$cached"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  emit_unavailable
  exit 0
fi

temp=$(read_temp 2>/dev/null || true)
if [[ -z "$temp" ]]; then
  output=$(emit_unavailable)
else
  output=$(emit_json "$temp")
fi

write_cache "$output"
printf '%s' "$output"

# Delegate to the Waybar temperature script (tmux status bar uses the same JSON).

#exec "${HOME}/.config/waybar/scripts/temperature.sh"

#!/usr/bin/env bash
# CPU temperature in Waybar JSON format: {"text","tooltip","class"}.
# macOS: macmon (Apple Silicon), osx-cpu-temp / istats (Intel fallbacks).
# Linux: sensors or thermal_zone sysfs.
