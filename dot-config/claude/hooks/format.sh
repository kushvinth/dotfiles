#!/usr/bin/env bash
# PostToolUse (Edit|MultiEdit|Write): run the language's standard formatter on
# the file Claude just touched, if it's installed. Never blocks Claude, but a
# nix parse error is reported back (exit 2) so it's fixed now, not at darnix.

file=$(jq -r '.tool_input.file_path // empty')
[ -f "$file" ] || exit 0

# is one of these files in the file's dir or above? Formatters that would
# restyle whole files only run in projects that state a style.
above() {
  local d f
  d=$(dirname "$file")
  while [ "$d" != / ]; do
    for f; do [ -e "$d/$f" ] && return 0; done
    d=$(dirname "$d")
  done
  return 1
}

case "$file" in
*.nix)
  if command -v nixfmt >/dev/null && ! err=$(nixfmt "$file" 2>&1); then
    printf 'nixfmt: %s\n' "$err" >&2
    exit 2
  fi
  ;;
*.go)
  if command -v gofumpt; then
    gofumpt -w "$file"
  elif command -v gofmt; then
    gofmt -w "$file"
  fi >/dev/null 2>&1
  ;;
*.sh | *.bash) above .editorconfig && command -v shfmt >/dev/null && shfmt -w "$file" >/dev/null 2>&1 ;;
*.py) above pyproject.toml ruff.toml && command -v ruff >/dev/null && ruff format -q "$file" >/dev/null 2>&1 ;;
esac

exit 0
