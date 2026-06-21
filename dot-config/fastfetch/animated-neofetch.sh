#!/bin/bash
# ── animated-neofetch.sh ────────────────────────────────
# Animated ASCII frames (left) + fastfetch system info (right)
# Usage: ./animated-neofetch.sh [delay] [loops]

delay=${1:-0.05}
loops=${2:-2}
ascii_row=1
ascii_col=1
text_col=60

config_dir="${HOME}/.config/fastfetch"
cache_file="${HOME}/.cache/fastfetch.txt"
mkdir -p "${HOME}/.cache"

padding=$(printf '%*s' $((text_col - 1)) '')

if [[ ! -f "$cache_file" || $(find "$cache_file" -mmin +60 2>/dev/null) ]]; then
  fastfetch --logo none --pipe false | sed "s/^/$padding/" > "$cache_file"
fi

clear
cat "$cache_file"

tput civis
trap 'tput cnorm' EXIT

shopt -s nullglob
frames=("${config_dir}/frames_colour"/*.txt)
shopt -u nullglob

if [[ ${#frames[@]} -eq 0 ]]; then
  echo "No frames found in ${config_dir}/frames_colour/"
  tput cnorm
  exit 1
fi

for ((c=0; c<loops; c++)); do
  for frame in "${frames[@]}"; do
    tput cup "$ascii_row" "$ascii_col"
    cat "$frame"
    sleep "$delay"
  done
done
