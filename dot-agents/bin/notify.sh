#!/usr/bin/env bash
# Push agent lifecycle events (Claude Code, Codex, opencode, gnhf, ...) to Gotify.
#
# Credentials are resolved in this order: environment, a per-user cache that
# `hydrate` writes from the macOS Keychain, then the Keychain directly. Only
# `hydrate` ever touches the Keychain, so sending a notification never blocks on
# a Touch ID prompt: ask once at session start, notify silently from then on.
#
#   notify.sh hydrate            resolve + cache creds (run at session start)
#   notify.sh <title> [message]  send a notification (message defaults to $PWD)
#   <hook json> | notify.sh      derive title/message from a hook payload (no arguments)
#   notify.sh '{"type":...}'     same, for Codex's notify (JSON as argument)
#
# A ping says what happened, then where:
#   what   the hook's own text: Claude's permission/idle message, or the last thing the agent said
#          (Claude Stop: read from the transcript; Codex: last-assistant-message), one line
#   where  instance (agent + terminal pane + session), repo (+ worktree), branch (+ uncommitted, ahead), directory
#   NOTIFY_INSTANCE="gnhf r6#2"   name this instance yourself (the gnhf launcher does)
#   NOTIFY_PLAIN=1                send the message exactly as given, no context block
#   NOTIFY_DRY_RUN=1              print the title and message instead of sending
# Sending happens in the background (a hook returns at once), the same ping is dropped if it was
# sent in the last 30 s, and the priority is never set here: Gotify uses the app's own default.
set -uo pipefail

URL_VAR="GOTIFY_URL"
TOKEN_VAR="GOTIFY_TOKEN"
URL_SVC="gotify-url"
TOKEN_SVC="gotify-token"
ACCOUNT="${USER:-$(id -un)}"
DEFAULT_URL="https://gotify.kushvinth.com"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agents"
CACHE="$CACHE_DIR/gotify.env"
LOG="$CACHE_DIR/notify.log"

HOST="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)"

mkdir -p "$CACHE_DIR" 2>/dev/null && chmod 700 "$CACHE_DIR" 2>/dev/null
: >>"$LOG" 2>/dev/null || LOG=""

log() {
  [ -n "$LOG" ] && printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >>"$LOG" 2>/dev/null
  return 0
}

kc() { /usr/bin/security find-generic-password -a "$ACCOUNT" -s "$1" -w 2>/dev/null; }

# Read the cache without clobbering any values already present in the env.
read_cache() {
  C_URL=""
  C_TOKEN=""
  if [ -r "$CACHE" ]; then
    # shellcheck disable=SC1090
    C_URL="$(
      . "$CACHE" 2>/dev/null
      printf '%s' "${GOTIFY_URL:-}"
    )"
    # shellcheck disable=SC1090
    C_TOKEN="$(
      . "$CACHE" 2>/dev/null
      printf '%s' "${GOTIFY_TOKEN:-}"
    )"
  fi
}

hydrate() {
  local url token exports
  url="${GOTIFY_URL:-}"
  [ -n "$url" ] || url="$C_URL"
  token="${GOTIFY_TOKEN:-}"
  [ -n "$token" ] || token="$C_TOKEN"

  # Read the Keychain directly first: silent when the item was created by
  # `security` (which is what `secret set` does), so a session never blocks.
  [ -n "$url" ] || url="$(kc "$URL_SVC")"
  [ -n "$token" ] || token="$(kc "$TOKEN_SVC")"

  # If that came back empty, ask the nix `secret` helper (one Touch ID covers
  # both values).
  if [ -z "$token" ] && command -v secret >/dev/null 2>&1; then
    if exports="$(secret env "$URL_VAR" "$TOKEN_VAR" 2>/dev/null)"; then
      eval "$exports"
      url="${GOTIFY_URL:-$url}"
      token="${GOTIFY_TOKEN:-$token}"
    fi
  fi
  [ -n "$url" ] || url="$DEFAULT_URL"

  if [ -z "$token" ]; then
    log "hydrate: no $TOKEN_VAR (env, cache, secret, keychain); nothing cached"
    return 1
  fi

  if ! (
    umask 077
    printf 'export %s=%q\n' "$URL_VAR" "$url" "$TOKEN_VAR" "$token" >"$CACHE"
  ); then
    log "hydrate: cannot write $CACHE; nothing cached"
    return 1
  fi
  chmod 600 "$CACHE" 2>/dev/null || :
  log "hydrate: cached $URL_VAR + $TOKEN_VAR (url=$url)"
  return 0
}

send() {
  local title="$1" message="$2" url token
  url="${GOTIFY_URL:-}"
  [ -n "$url" ] || url="$C_URL"
  token="${GOTIFY_TOKEN:-}"
  [ -n "$token" ] || token="$C_TOKEN"
  [ -n "$url" ] || url="$DEFAULT_URL"

  if [ -z "$token" ]; then
    log "send: no token cached yet; skipped (title=$title) — run: notify.sh hydrate"
    return 0
  fi

  # token in a header, not the URL, so it stays out of proxy and server access logs
  if curl -sS --max-time 5 --retry-max-time 12 \
    --retry 4 --retry-delay 1 --retry-all-errors --retry-connrefused \
    -X POST "${url%/}/message" \
    -H "X-Gotify-Key: ${token}" \
    --form-string "title=${HOST}: ${title}" \
    --form-string "message=${message}" >/dev/null 2>&1; then # -F reads a file for a leading @ or <
    log "send: ok (title=$title)"
  else
    log "send: FAILED (title=$title)"
  fi
  return 0
}

# true when the same title+message went out in the last 30 seconds (repeated idle prompts, double hooks)
recently_sent() {
  # in $TMPDIR, not $CACHE_DIR: agent-jail denies writes there, which turned dedup off for jailed agents
  local key now last_key last_ts stamp="${TMPDIR:-/tmp}/agents-notify-last-sent"
  key="$(printf '%s\n%s' "$1" "$2" | shasum 2>/dev/null | cut -c1-16)"
  [ -n "$key" ] || return 1 # no shasum: send rather than match every empty key
  now="$(date +%s)"
  if [ -r "$stamp" ] && read -r last_ts last_key <"$stamp" 2>/dev/null; then
    if [ "$last_key" = "$key" ] && [ $((now - ${last_ts:-0})) -lt 30 ]; then return 0; fi
  fi
  printf '%s %s\n' "$now" "$key" >"$stamp" 2>/dev/null
  return 1
}

# keep the log to its last 500 lines
trim_log() {
  [ -n "$LOG" ] && [ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 1000 ] || return 0
  tail -n 500 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
}

# One pass over the hook payload: prints the title (line 1), then the message. Reads the JSON from
# Claude Code (stdin), Codex (argument) or opencode (stdin), asks git about the directory, never fails.
describe() {
  N_TITLE="$1" N_MESSAGE="$2" N_JSON="$3" N_PWD="$PWD" N_PLAIN="${NOTIFY_PLAIN:-}" python3 - <<'PY' 2>/dev/null
import json, os, subprocess

def run(*a, cwd=None):
    if a[0] == "git":  # this hook runs unsandboxed: the repo's config must not run commands
        a = ("git", "-c", "core.fsmonitor=false") + a[1:]
    try:
        return subprocess.run(a, cwd=cwd, capture_output=True, text=True, timeout=3).stdout.strip()
    except Exception:
        return ""

def one_line(text, n=180):
    text = " ".join(str(text or "").split())
    return text if len(text) <= n else text[: n - 1].rstrip() + "…"

def last_said(path):
    """The last text the assistant wrote, from a Claude Code transcript (JSONL)."""
    try:
        with open(os.path.expanduser(path), "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 400_000))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get("type") != "assistant":
            continue
        texts = [c.get("text", "") for c in (e.get("message") or {}).get("content") or [] if isinstance(c, dict) and c.get("type") == "text"]
        if any(t.strip() for t in texts):
            return " ".join(texts)
    return ""

try:
    p = json.loads(os.environ.get("N_JSON") or "{}")
    p = p if isinstance(p, dict) else {}
except Exception:
    p = {}

event = p.get("hook_event_name") or p.get("type") or ""
named = {"agent-turn-complete": "codex: finished", "Stop": "claude: finished", "Notification": "claude: input needed",
         "StopFailure": "claude: failed", "session.idle": "opencode: finished"}
title = os.environ.get("N_TITLE") or named.get(event) or event or "agent"
message = os.environ.get("N_MESSAGE", "")
cwd = p.get("cwd") or os.environ.get("N_PWD") or "."
if message == cwd:
    message = ""

# what happened
what = message or p.get("message") or p.get("last-assistant-message") or p.get("last_assistant_message") or ""
if not what and p.get("transcript_path") and event in ("Stop", "SubagentStop", ""):
    what = last_said(p["transcript_path"])

if os.environ.get("N_PLAIN") == "1":
    print(title)
    print(message or os.path.basename(cwd))
    raise SystemExit

# where: instance, repo, branch, dir
home = os.path.expanduser("~")
short = lambda d: ("~" + d[len(home):]) if d.startswith(home) else d
lines = [one_line(what)] if what else []
instance = os.environ.get("NOTIFY_INSTANCE", "").strip()
if not instance:
    bits = [title.split(":", 1)[0] if ":" in title else ""]
    if os.environ.get("TMUX"):
        win = run("tmux", "display-message", "-p", "#S:#W")
        bits.append(f"tmux {win}" if win else "tmux")
    elif os.environ.get("ZELLIJ_SESSION_NAME"):
        bits.append(f"zellij {os.environ['ZELLIJ_SESSION_NAME']} pane {os.environ.get('ZELLIJ_PANE_ID', '?')}")
    sid = (p.get("session_id") or p.get("thread-id") or os.environ.get("CLAUDE_SESSION_ID") or "")[:8]
    if sid:
        bits.append(f"session {sid}")
    instance = " · ".join(b for b in bits if b)
if instance:
    lines.append(f"instance: {instance}")
top = run("git", "rev-parse", "--show-toplevel", cwd=cwd)
if top:
    common = run("git", "rev-parse", "--path-format=absolute", "--git-common-dir", cwd=cwd)
    main_repo = os.path.basename(os.path.dirname(common)) if common.endswith("/.git") else os.path.basename(top)
    repo = main_repo + (f" (worktree {os.path.basename(top)})" if os.path.basename(top) != main_repo else "")
    branch = run("git", "rev-parse", "--abbrev-ref", "HEAD", cwd=cwd)
    if branch == "HEAD":
        branch = "detached @ " + run("git", "rev-parse", "--short", "HEAD", cwd=cwd)
    extra = []
    # dirty: skip edits inside submodules, which cost ~0.2 s in a repo with many (~/dotfiles)
    dirty = len([l for l in run("git", "status", "--porcelain", "-uno", "--ignore-submodules=dirty", cwd=cwd).splitlines() if l.strip()])
    if dirty:
        extra.append(f"{dirty} uncommitted")
    ahead = run("git", "rev-list", "--count", "@{upstream}..HEAD", cwd=cwd)
    if ahead.isdigit() and int(ahead):
        extra.append(f"{ahead} unpushed")
    lines.append(f"repo: {repo}")
    lines.append(f"branch: {branch}" + (f" ({', '.join(extra)})" if extra else ""))
    title += f" · {main_repo}@{branch}"
lines.append(f"dir: {short(cwd)}")
print(title)
print("\n".join(lines))
PY
}

main() {
  read_cache

  if [ "${1:-}" = "hydrate" ]; then
    hydrate
    return $?
  fi

  local title="" message="" json=""
  if [ $# -ge 1 ] && [ "${1:0:1}" = "{" ]; then
    json="$1" # Codex: JSON as the argument
  elif [ $# -ge 1 ] && [ "${1:-}" != "-" ]; then
    title="$1"
    message="${2:-}" # stdin is left alone: hooks pass no arguments, and a caller's read loop keeps its input
  elif [ ! -t 0 ]; then
    json="$(cat 2>/dev/null || true)" # Claude Code / opencode: JSON on stdin
  fi

  if [ "${NOTIFY_DRY_RUN:-}" = 1 ]; then
    deliver "$title" "$message" "$json"
    return 0
  fi
  # describe asks git (~0.1-0.3 s): do it with the send in the background, so the hook returns at once
  deliver "$title" "$message" "$json" </dev/null >/dev/null 2>&1 &
  return 0
}

deliver() {
  local title="$1" message="$2" out
  out="$(describe "$title" "$message" "$3")"
  if [ -n "$out" ]; then
    title="${out%%$'\n'*}"
    message="${out#*$'\n'}"
  else # no python3: still send something
    title="${title:-agent}"
    message="${message:-$(basename "$PWD")}"
  fi

  if [ "${NOTIFY_DRY_RUN:-}" = 1 ]; then
    printf 'TITLE: %s: %s\n%s\n' "$HOST" "$title" "$message"
    return 0
  fi # preview, nothing is sent
  if recently_sent "$title" "$message"; then
    log "send: duplicate within 30s, skipped (title=$title)"
    return 0
  fi
  trim_log
  send "$title" "$message"
}

main "$@"
