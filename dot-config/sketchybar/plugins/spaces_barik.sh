#!/bin/bash
# Barik-style workspace pills (see barik/Barik/Widgets/Spaces/SpacesWidget.swift)

command -v sketchybar >/dev/null 2>&1 || exit 0
command -v yabai >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

SENDER="${SENDER:-}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="${PLUGIN_DIR:-$CONFIG_DIR/plugins}"
[ -z "${WHITE:-}" ] && source "$CONFIG_DIR/colors.sh" 2>/dev/null || true
FONT="${FONT:-SF Pro}"

# Barik dark-mode palette (Assets.xcassets)
export BARIK_FG="${SPACES_TEXT_COLOR:-0xE6FFFFFF}"
export BARIK_ACTIVE_BG="${SPACES_ACTIVE_COLOR:-0x66FFFFFF}"
export BARIK_INACTIVE_BG="${SPACES_INACTIVE_COLOR:-0x1AFFFFFF}"
export BARIK_SHADOW="${SPACES_SHADOW_COLOR:-0x80000000}"

export SPACES_SHOW_KEY="${SPACES_SHOW_KEY:-true}"
export SPACES_SHOW_WINDOW_TITLE="${SPACES_SHOW_WINDOW_TITLE:-true}"
export SPACES_SHOW_EMPTY="${SPACES_SHOW_EMPTY:-false}"
export SPACES_TITLE_MAX_LENGTH="${SPACES_TITLE_MAX_LENGTH:-50}"
export SPACES_ITEM_PREFIX="${SPACES_ITEM_PREFIX:-barik.ws}"
export SPACES_MAX_APPS="${SPACES_MAX_APPS:-12}"
export SPACES_MAX_SPACES="${SPACES_MAX_SPACES:-9}"

CACHE_FILE="${SPACES_CACHE_FILE:-${TMPDIR:-/tmp}/sketchybar-barik-spaces}"
STATE_FILE="${SPACES_STATE_FILE:-${CACHE_FILE}.state}"
LOCK_FILE="${SPACES_LOCK_FILE:-${TMPDIR:-/tmp}/sketchybar-barik.lock}"
POOL_READY="${SPACES_POOL_READY:-${CACHE_FILE}.pool}"

# Animation timing (sketchybar steps are 60Hz-based; keep low for snappy 120/144Hz panels)
ANIM_SPACE="${SPACES_ANIM_SPACE:-3}"
ANIM_APP="${SPACES_ANIM_APP:-3}"
ANIM_CURVE="${SPACES_ANIM_CURVE:-circ}"

name_key()  { echo "${SPACES_ITEM_PREFIX}.$1.key"; }
name_app()  { echo "${SPACES_ITEM_PREFIX}.$1.app.$2"; }
name_title(){ echo "${SPACES_ITEM_PREFIX}.$1.title"; }
name_brk()  { echo "${SPACES_ITEM_PREFIX}.$1.bracket"; }

item_exists() {
  sketchybar --query "$1" &>/dev/null
}

animations_enabled() {
  case "${SENDER:-}" in
    forced|""|windows_on_spaces|system_woke) return 1 ;;
    *) return 0 ;;
  esac
}

state_get() {
  local key=$1
  [ -f "$STATE_FILE" ] || return 1
  jq -r --arg k "$key" '.[$k] // empty' "$STATE_FILE" 2>/dev/null
}

state_space_get() {
  local safe=$1 field=$2
  [ -f "$STATE_FILE" ] || return 1
  jq -r --arg s "$safe" --arg f "$field" '.spaces[$s][$f] // empty' "$STATE_FILE" 2>/dev/null
}

animate_bracket_focus() {
  local brk=$1 active=$2 do_anim=$3
  local color=$BARIK_INACTIVE_BG
  [ "$active" = "1" ] && color=$BARIK_ACTIVE_BG

  if animations_enabled && [ "$do_anim" = "1" ] && [ "${ANIM_SPACE:-0}" -gt 0 ]; then
    sketchybar --animate "$ANIM_CURVE" "$ANIM_SPACE" --set "$brk" \
      background.drawing=on \
      background.color="$color" \
      background.border_width=0
  else
    sketchybar --set "$brk" \
      background.drawing=on \
      background.color="$color" \
      background.border_width=0
  fi
}

# Ease to target scale only (no shrink-then-grow)
animate_app_icon() {
  local item=$1 scale=$2 app_changed=$3

  if ! animations_enabled || [ "$app_changed" != "1" ] || [ "${ANIM_APP:-0}" -le 0 ]; then
    sketchybar --set "$item" \
      drawing=on \
      background.drawing=off \
      icon.background.drawing=on \
      icon.background.image.scale="$scale"
    return
  fi

  sketchybar --animate "$ANIM_CURVE" "$ANIM_APP" --set "$item" \
    drawing=on \
    background.drawing=off \
    icon.background.drawing=on \
    icon.background.image.scale="$scale"
}

set_title() {
  local item=$1 title=$2

  if [ -z "$title" ]; then
    sketchybar --set "$item" drawing=off label.drawing=off
    return
  fi

  sketchybar --set "$item" \
    drawing=on label.drawing=on label="$title" label.color="$BARIK_FG"
}

create_space_items() {
  local sid=$1 safe=$2
  local key app title brk
  key=$(name_key "$safe")
  title=$(name_title "$safe")
  brk=$(name_brk "$safe")

  if item_exists "$brk"; then
    return
  fi

  local -a members=()

  sketchybar --add item "$key" left \
    --set "$key" \
      icon.drawing=off \
      label.drawing=on \
      label.font="$FONT:Semibold:13.0" \
      label.color="$BARIK_FG" \
      padding_left=10 \
      padding_right=5 \
      background.drawing=off \
      click_script="yabai -m space --focus $sid"

  members+=("$key")

  local j
  for j in $(seq 1 "$SPACES_MAX_APPS"); do
    app=$(name_app "$safe" "$j")
    sketchybar --add item "$app" left \
      --set "$app" \
        drawing=off \
        label.drawing=off \
        background.drawing=off \
        icon.drawing=on \
        icon.padding_left=0 \
        icon.padding_right=0 \
        icon.background.height=21 \
        icon.background.corner_radius=0 \
        icon.background.border_width=0 \
        icon.background.drawing=off \
        icon.background.image.scale=1.0 \
        icon.background.image.clip=0.85 \
        padding_left=2 \
        padding_right=2 \
        click_script="yabai -m space --focus $sid"
    members+=("$app")
  done

  sketchybar --add item "$title" left \
    --set "$title" \
      icon.drawing=off \
      label.drawing=off \
      label.font="$FONT:Semibold:13.0" \
      label.color="$BARIK_FG" \
      padding_left=5 \
      padding_right=10 \
      background.drawing=off \
      click_script="yabai -m space --focus $sid"

  members+=("$title")

  sketchybar --add bracket "$brk" "${members[@]}" \
    --set "$brk" \
      background.height=30 \
      background.corner_radius=8 \
      background.drawing=on \
      background.shadow.drawing=off \
      padding_left=0 \
      padding_right=8 \
      click_script="yabai -m space --focus $sid"

  hide_space_items "$safe"
}

ensure_space_pool() {
  if [ -f "$POOL_READY" ] && item_exists "$(name_brk 1)"; then
    return
  fi
  local sid
  for sid in $(seq 1 "$SPACES_MAX_SPACES"); do
    create_space_items "$sid" "$sid"
  done
  touch "$POOL_READY"
}

hide_space_items() {
  local safe=$1
  local brk
  brk=$(name_brk "$safe")
  sketchybar --set "$brk" drawing=off background.drawing=off 2>/dev/null || true
  sketchybar --set "$(name_key "$safe")" drawing=off label.drawing=off 2>/dev/null || true
  sketchybar --set "$(name_title "$safe")" drawing=off label.drawing=off 2>/dev/null || true
  local j
  for j in $(seq 1 "$SPACES_MAX_APPS"); do
    clear_app_slot "$(name_app "$safe" "$j")"
  done
}

show_space_visible() {
  local safe=$1
  sketchybar --set "$(name_brk "$safe")" drawing=on 2>/dev/null || true
}

bracket_to_safe() {
  local brk=$1
  local safe="${brk#${SPACES_ITEM_PREFIX}.}"
  echo "${safe%.bracket}"
}

clear_app_slot() {
  local item=$1
  sketchybar --set "$item" \
    drawing=off \
    background.drawing=off \
    icon.background.drawing=off \
    icon.background.image="" \
    icon.background.image.scale=1.0 2>/dev/null || true
}

remove_space_items() {
  local safe=$1
  local brk
  brk=$(name_brk "$safe")

  local j
  for j in $(seq 1 "$SPACES_MAX_APPS"); do
    clear_app_slot "$(name_app "$safe" "$j")"
    sketchybar --remove "$(name_app "$safe" "$j")" 2>/dev/null || true
  done

  sketchybar --remove "$(name_key "$safe")" 2>/dev/null || true
  sketchybar --remove "$(name_title "$safe")" 2>/dev/null || true
  sketchybar --remove "$brk" 2>/dev/null || true
}

# Remove barik brackets outside the fixed 1..MAX_SPACES pool (legacy/orphans)
reconcile_stale_brackets() {
  local query names name safe

  query=$(sketchybar --query '/'"${SPACES_ITEM_PREFIX}"'\.[^.]+\.bracket/' 2>/dev/null) || return 0
  names=$(echo "$query" | jq -r 'if type == "array" then .[].name else .name end' 2>/dev/null) || return 0

  while IFS= read -r name; do
    [ -z "$name" ] && continue
    safe=$(bracket_to_safe "$name")
    [[ "$safe" =~ ^[0-9]+$ ]] && [ "$safe" -ge 1 ] && [ "$safe" -le "$SPACES_MAX_SPACES" ] && continue
    remove_space_items "$safe"
  done <<< "$names"
}

# Outputs lines: sid<TAB>safe<TAB>focused<TAB>apps_json<TAB>title
fetch_spaces() {
  python3 - <<'PY'
import json, os, re, subprocess, sys

show_empty = os.environ.get("SPACES_SHOW_EMPTY", "false").lower() == "true"
show_key = os.environ.get("SPACES_SHOW_KEY", "true").lower() == "true"
show_title = os.environ.get("SPACES_SHOW_WINDOW_TITLE", "true").lower() == "true"
max_len = int(os.environ.get("SPACES_TITLE_MAX_LENGTH", "50"))
max_apps = int(os.environ.get("SPACES_MAX_APPS", "12"))
max_spaces = int(os.environ.get("SPACES_MAX_SPACES", "9"))
always_display = [
    x.strip() for x in os.environ.get("SPACES_ALWAYS_SHOW_APP_FOR", "").split(",") if x.strip()
]

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

def safe_id(space_id):
    return re.sub(r"[^A-Za-z0-9_-]", "_", str(space_id))

spaces_raw = run(["yabai", "-m", "query", "--spaces"])
windows_raw = run(["yabai", "-m", "query", "--windows"])
if not spaces_raw or not windows_raw:
    sys.exit(0)

spaces = json.loads(spaces_raw)
windows = json.loads(windows_raw)

space_map = {
    str(s["index"]): {
        "id": str(s["index"]),
        "focused": s.get("has-focus", False),
        "windows": [],
    }
    for s in spaces
}

for w in windows:
    if w.get("is-hidden") or w.get("is-floating") or w.get("is-sticky"):
        continue
    sid = str(w.get("space"))
    if sid not in space_map:
        continue
    space_map[sid]["windows"].append({
        "id": w.get("id"),
        "app": w.get("app") or "",
        "title": w.get("title") or "",
        "focused": w.get("has-focus", False),
        "stack_index": w.get("stack-index", 0),
    })

for sid_int in range(1, max_spaces + 1):
    sid = str(sid_int)
    space = space_map.get(sid)
    if space is None:
        continue
    space["windows"].sort(key=lambda w: w.get("stack_index", 0))
    if not show_empty and not space["windows"]:
        print(
            f"{sid}\t{sid}\t{1 if space.get('focused') else 0}\t"
            f"{1 if show_key else 0}\t[]\t"
        )
        continue

    focused_win = next((w for w in space["windows"] if w.get("focused")), None)
    title = ""
    if focused_win and show_title and space.get("focused"):
        app = focused_win.get("app") or ""
        win_title = focused_win.get("title") or ""
        same = sum(1 for w in space["windows"] if w.get("app") == app)
        if app and (same <= 1 or app in always_display):
            title = app
        else:
            title = win_title or app
        if len(title) > max_len:
            title = title[:max_len] + "..."

    wins = sorted(
        space["windows"],
        key=lambda w: (not w.get("focused", False), w.get("stack_index", 0)),
    )
    apps = []
    for w in wins:
        app = w.get("app") or ""
        if not app:
            continue
        apps.append({
            "id": w.get("id"),
            "app": app,
            "focused": w.get("focused", False),
        })
        if len(apps) >= max_apps:
            break

    import json as _json
    apps_json = _json.dumps(apps)
    print(
        f"{sid}\t{sid}\t"
        f"{1 if space.get('focused') else 0}\t"
        f"{1 if show_key else 0}\t"
        f"{apps_json}\t{title.replace(chr(9), ' ').replace(chr(10), ' ')}"
    )
PY
}

lookup_space_line() {
  local sid=$1 entries=$2
  echo "$entries" | awk -F'\t' -v s="$sid" '$1 == s { print; exit }'
}

PENDING_FILE="${LOCK_FILE}.pending"

acquire_lock() {
  local lockdir="${LOCK_FILE}.d" i=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -gt 50 ] && return 1
    sleep 0.001
  done
  return 0
}

release_lock() {
  rmdir "${LOCK_FILE}.d" 2>/dev/null || true
}

mark_pending_update() {
  : >"$PENDING_FILE"
}

space_window_count() {
  yabai -m query --windows --space "$1" 2>/dev/null | jq '
    [.[] | select((."is-floating"|not) and (."is-sticky"|not) and (."is-hidden"|not))] | length'
}

# Fast path: space switch only — skip slow python when layout per space is unchanged
quick_focus_update() {
  case "${SENDER:-}" in
    space_change|window_focus|windows_on_spaces) ;;
    *) return 1 ;;
  esac

  local prev_focus new_focus sid brk apps_json win_count j scale focused_flag
  local yabai_count state_count
  prev_focus="$(state_get focused_safe)"
  new_focus="$(yabai -m query --spaces 2>/dev/null | jq -r '.[] | select(.["has-focus"]) | .index' | head -1)"
  [ -z "$new_focus" ] || [ "$new_focus" = "null" ] && return 1
  [ "$prev_focus" = "$new_focus" ] && return 1

  for sid in $(seq 1 "$SPACES_MAX_SPACES"); do
    yabai_count=$(space_window_count "$sid")
    state_count=$(state_space_get "$sid" apps_json | jq 'length' 2>/dev/null)
    [ -z "$state_count" ] || [ "$state_count" = "null" ] && state_count=0
    [ "$yabai_count" != "$state_count" ] && return 1
  done

  item_exists "$(name_brk "$new_focus")" || return 1

  for sid in $(seq 1 "$SPACES_MAX_SPACES"); do
    brk=$(name_brk "$sid")
    item_exists "$brk" || continue
    if [ "$sid" = "$new_focus" ]; then
      animate_bracket_focus "$brk" 1 1
    elif [ "$sid" = "$prev_focus" ]; then
      animate_bracket_focus "$brk" 0 1
    fi

    apps_json="$(state_space_get "$sid" apps_json)"
    [ -z "$apps_json" ] || [ "$apps_json" = "null" ] && continue
    win_count=$(echo "$apps_json" | jq 'length')
    [ "$win_count" = "0" ] || [ "$win_count" = "null" ] && continue

    j=1
    while [ "$j" -le "$win_count" ] && [ "$j" -le "$SPACES_MAX_APPS" ]; do
      focused_flag=$(echo "$apps_json" | jq -r ".[$((j - 1))].focused")
      scale=0.85
      if [ "$sid" = "$new_focus" ] && [ "$focused_flag" = "true" ]; then
        scale="${SPACES_FOCUS_ICON_SCALE:-1.06}"
      elif [ "$sid" != "$new_focus" ]; then
        scale=1.0
      fi
      animate_app_icon "$(name_app "$sid" "$j")" "$scale" 1
      j=$((j + 1))
    done
  done

  if [ -f "$STATE_FILE" ]; then
    jq --arg fs "$new_focus" '.focused_safe = $fs' "$STATE_FILE" >"${STATE_FILE}.next" \
      && mv "${STATE_FILE}.next" "$STATE_FILE"
  fi
  return 0
}

update_all_once() {
  trap release_lock EXIT

  ensure_space_pool

  local entries
  entries="$(fetch_spaces)" || entries=""

  local prev_focused_safe=""
  prev_focused_safe="$(state_get focused_safe)"

  local new_focused_safe=""
  local state_tmp
  state_tmp="$(mktemp "${TMPDIR:-/tmp}/sketchybar-barik-state.XXXXXX")"
  echo '{"focused_safe":"","spaces":{}}' >"$state_tmp"

  local sid safe focused show_key apps_json title line brk key
  local prev_slot prev_apps_json bracket_focus_changed
  local win_count j idx app focused_flag app_item scale app_changed prev_app
  local focused_slot title_item

  for sid in $(seq 1 "$SPACES_MAX_SPACES"); do
    safe="$sid"
    brk=$(name_brk "$safe")
    key=$(name_key "$safe")

    line="$(lookup_space_line "$sid" "$entries")"
    if [ -z "$line" ]; then
      hide_space_items "$safe"
      continue
    fi

    IFS=$'\t' read -r _sid safe focused show_key apps_json title <<<"$line"

    win_count=$(echo "$apps_json" | jq 'length')
    if [ "$win_count" = "0" ] || [ "$win_count" = "null" ]; then
      hide_space_items "$safe"
      continue
    fi

    show_space_visible "$safe"
    [ "$focused" = "1" ] && new_focused_safe="$safe"

    prev_slot="$(state_space_get "$safe" focused_slot)"
    prev_apps_json="$(state_space_get "$safe" apps_json)"

    bracket_focus_changed=0
    if [ "$focused" = "1" ] && [ "$safe" != "$prev_focused_safe" ]; then
      bracket_focus_changed=1
    elif [ "$focused" = "0" ] && [ "$safe" = "$prev_focused_safe" ]; then
      bracket_focus_changed=1
    fi

    if [ "$show_key" = "1" ]; then
      sketchybar --set "$key" drawing=on label.drawing=on label="$sid"
    else
      sketchybar --set "$key" drawing=off label.drawing=off
    fi

    j=1
    focused_slot=0
    for idx in $(seq 0 $((win_count - 1))); do
      [ "$j" -gt "$SPACES_MAX_APPS" ] && break
      app=$(echo "$apps_json" | jq -r ".[$idx].app")
      focused_flag=$(echo "$apps_json" | jq -r ".[$idx].focused")
      app_item=$(name_app "$safe" "$j")

      scale=0.85
      if [ "$focused" = "1" ] && [ "$focused_flag" = "true" ]; then
        scale="${SPACES_FOCUS_ICON_SCALE:-1.06}"
      elif [ "$focused" != "1" ]; then
        scale=1.0
      fi

      app_changed=0
      prev_app=$(echo "$prev_apps_json" | jq -r ".[$((j - 1))].app // empty" 2>/dev/null)
      [ "$prev_app" != "$app" ] && app_changed=1
      [ "$prev_slot" != "$j" ] && [ "$focused_flag" = "true" ] && app_changed=1

      sketchybar --set "$app_item" \
        icon.background.image="app.$app" \
        icon.background.drawing=on \
        background.drawing=off
      animate_app_icon "$app_item" "$scale" "$app_changed"

      [ "$focused_flag" = "true" ] && focused_slot=$j
      j=$((j + 1))
    done

    for k in $(seq "$j" "$SPACES_MAX_APPS"); do
      clear_app_slot "$(name_app "$safe" "$k")"
    done

    title_item=$(name_title "$safe")
    if [ "$focused" = "1" ] && [ -n "$title" ]; then
      set_title "$title_item" "$title"
    else
      sketchybar --set "$title_item" drawing=off label.drawing=off
    fi

    animate_bracket_focus "$brk" "$focused" "$bracket_focus_changed"

    jq \
      --arg safe "$safe" \
      --argjson slot "$focused_slot" \
      --arg title "$title" \
      --argjson apps "$apps_json" \
      '.spaces[$safe] = {focused_slot: $slot, title: $title, apps_json: $apps}' \
      "$state_tmp" >"${state_tmp}.next" && mv "${state_tmp}.next" "$state_tmp"
  done

  jq --arg fs "$new_focused_safe" '.focused_safe = $fs' "$state_tmp" >"${state_tmp}.next" \
    && mv "${state_tmp}.next" "$state_tmp"

  reconcile_stale_brackets

  {
    for sid in $(seq 1 "$SPACES_MAX_SPACES"); do
      echo "$(name_brk "$sid")"
    done
  } >"$CACHE_FILE"

  mv "$state_tmp" "$STATE_FILE"
  release_lock
  trap - EXIT
}

update_all() {
  if ! acquire_lock; then
    mark_pending_update
    return
  fi

  if quick_focus_update; then
    while [ -f "$PENDING_FILE" ]; do
      rm -f "$PENDING_FILE"
      update_all_once
    done
    release_lock
    trap - EXIT
    return
  fi

  update_all_once

  while [ -f "$PENDING_FILE" ]; do
    rm -f "$PENDING_FILE"
    acquire_lock || break
    update_all_once
  done
}

case "$SENDER" in
  ""|forced|space_change|window_focus|windows_on_spaces|system_woke)
    update_all
    ;;
esac
