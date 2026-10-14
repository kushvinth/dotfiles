#!/usr/bin/env bash
# Claude Code status line: dir (branch*) · model · ctx % · 5h limit %
# Reads the session JSON on stdin; see `statusLine` in settings.json.

input=$(cat)
IFS=$'\x1f' read -r dir model ctx five week <<<"$(jq -r '[
  .workspace.current_dir // .cwd // "",
  .model.display_name // "",
  (.context_window.used_percentage // "" | tostring),
  (.rate_limits.five_hour.used_percentage // "" | tostring),
  (.rate_limits.seven_day.used_percentage // "" | tostring)
] | join("\u001f")' <<<"$input")"

dim=$'\e[2m' bold=$'\e[1m' reset=$'\e[0m'
green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' magenta=$'\e[35m' cyan=$'\e[36m'
sep=" ${dim}·${reset} "

# green < 50% ≤ yellow < 80% ≤ red
pct() {
  local n color
  n=$(printf '%.0f' "$1")
  if ((n >= 80)); then color=$red; elif ((n >= 50)); then color=$yellow; else color=$green; fi
  printf '%s%s%%%s' "$color" "$n" "$reset"
}

out="${bold}${cyan}$(basename "$dir")${reset}"

branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short HEAD 2>/dev/null ||
  git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  # -uno: skip untracked files so big repos stay fast
  [ -n "$(git --no-optional-locks -C "$dir" status --porcelain -uno 2>/dev/null | head -1)" ] && branch="$branch*"
  out+=" ${magenta}(${branch})${reset}"
fi

[ -n "$model" ] && out+="${sep}${model}"
[ -n "$ctx" ] && out+="${sep}ctx $(pct "$ctx")"
[ -n "$five" ] && out+="${sep}5h $(pct "$five")"
# weekly cap only once it starts to matter
[ -n "$week" ] && (($(printf '%.0f' "$week") >= 50)) && out+="${sep}7d $(pct "$week")"

printf '%s' "$out"
