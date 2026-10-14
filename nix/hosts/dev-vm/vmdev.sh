# Guest half of `dev` (dot-config/zsh/.zshalias), run as root in the dev VM:
# sudoAlphaX's dev.zsh with systemd-nspawn on NixOS. One throwaway container per
# project, booted --ephemeral from a tiny template whose init is the shared
# container closure (/etc/dev/ct-system).
#   vmdev up NAME SRC DOTS STAMP [GIT_NAME GIT_EMAIL [TZ]]
#     exit 3: the VM config is older than STAMP (the Mac rebuilds, then retries)
#     prints "name=CONTAINER" (NAME, or the one already running for SRC),
#     "login" when the containers' Claude or gh sign-in is missing,
#     "outdated" when it runs but predates the last VM update
#   vmdev stamp STAMP   (after a rebuild)
#   vmdev down NAME [SRC]
#   vmdev ls
#   vmdev sessions   (live zellij sessions in all containers)
template=/var/lib/machines/dev-template
state=/var/lib/dev/state
# One GC root per running container: the closure it booted. Without it, the
# weekly `nix-collect-garbage --delete-older-than` can delete the old system
# out from under a container that outlived its VM generation.
roots=/nix/var/nix/gcroots/dev

running() { machinectl show "$1" >/dev/null 2>&1; }
# The running container whose project is $1, whatever it is called (names are
# lossy: my-app and my_app map to the same one). nspawn needs ':' escaped.
by_src() {
  local m
  for m in $(machinectl list --no-legend | cut -d' ' -f1); do
    if systemctl show "$m" -p ExecStart --value | grep -qF -- "--bind=${1//:/\\:}:/home/dev/"; then
      echo "$m"
      return
    fi
  done
}
# nspawn can't delete its --ephemeral copy (NixOS makes var/empty immutable),
# so copies (a few KB each) no running container uses are cleared here, with
# their lock files; and GC roots of containers that no longer run.
sweep() {
  local keep=" " m d
  for m in $(machinectl list --no-legend | cut -d' ' -f1); do
    keep+="$(machinectl show "$m" -p RootDirectory --value) "
  done
  for d in "/var/lib/machines/.#snapshot.dev-template"*; do
    [[ -e $d && $keep != *" $d "* ]] || continue
    chattr -R -i "$d" 2>/dev/null || true
    rm -rf "$d"
  done
  for d in "/var/lib/machines/.#.#snapshot.dev-template"*.lck; do
    [[ -e $d && ! -e /var/lib/machines/${d#/var/lib/machines/.#} ]] || continue
    rm -f "$d"
  done
  for d in "$roots"/*; do
    [[ -e $d || -L $d ]] && ! running "${d##*/}" && rm -f "$d"
  done
  return 0
}

# One up/down at a time: `dev` in two tabs at once would race on the shared
# settings.json/.claude.json rewrites below (one wins, the other exits 1).
if [[ ${1-} == up || ${1-} == down ]]; then
  exec 9>/run/vmdev.lock
  flock 9
fi

case ${1-} in
up)
  name=$2 src=$3 dots=$4
  [[ $(cat /var/lib/dev/stamp 2>/dev/null) == "$5" ]] || exit 3
  [[ $name =~ ^dev-[A-Za-z0-9-]{1,60}$ ]] || { echo "vmdev: bad name: $name" >&2; exit 1; }
  # Only directories shared from the Mac, never the VM's own files.
  [[ -d $src && $(findmnt -no FSTYPE -T "$src") == virtiofs ]] || { echo "vmdev: not a Mac share: $src" >&2; exit 1; }
  found=$(by_src "$src")
  if [[ -n $found ]]; then
    name=$found
  elif running "$name"; then # taken by another project
    name="${name:0:55}-$(sha256sum <<<"$src" | cut -c1-8)"
  fi
  echo "name=$name"
  # The Mac's timezone: containers copy the VM's at boot (nspawn --timezone=auto).
  if [[ -n ${8-} && $(timedatectl show -p Timezone --value) != "$8" ]]; then
    timedatectl set-timezone "$8" || true
  fi
  for f in claude/.credentials.json gh/hosts.yml; do # codex is optional
    [[ -s $state/$f ]] || { echo login; break; }
  done
  # Claude here: your Mac settings (hooks, deny rules, statusline, plugins)
  # without the `ask` rules, which prompt even in bypassPermissions (set in
  # container.nix). Regenerated every run, so Mac edits carry over.
  cfg=$state/claude/settings.json
  rm -f "$cfg.tmp"
  jq 'del(.permissions.ask)' "$dots/dot-config/claude/settings.json" >"$cfg.tmp" &&
    chown 501:100 "$cfg.tmp" && mv -f "$cfg.tmp" "$cfg"
  # Trust the project folder, so Claude doesn't ask (only once there is a
  # ~/.claude.json, i.e. after the first sign-in). Skipped while any Claude
  # runs: it rewrites that file too, and one of the two writes would be lost
  # (Claude then asks once and records the answer itself).
  json=$state/claude/.claude.json
  if [[ -s $json ]] && ! pgrep '^\.?claude(-wrapped)?$' >/dev/null && ! jq -e --arg p "/home/dev/${src##*/}" '.projects[$p].hasTrustDialogAccepted' "$json" >/dev/null; then
    jq --arg p "/home/dev/${src##*/}" '.projects[$p].hasTrustDialogAccepted = true' "$json" >"$json.tmp" &&
      chown 501:100 "$json.tmp" && chmod 600 "$json.tmp" && mv -f "$json.tmp" "$json"
  fi

  if running "$name"; then
    # Booted before the last VM update: still on the old tools/config.
    started=$(systemctl show "$name" -p ActiveEnterTimestamp --value)
    (($(date -d "$started" +%s) < $(stat -c %Y /var/lib/dev/stamp))) && echo outdated
    exit 0
  fi

  ct=$(readlink -f /etc/dev/ct-system)
  ln -sfn "$ct/init" "$template/sbin/init"
  sweep
  mkdir -p "$roots" && ln -sfn "$ct" "$roots/$name"
  systemctl reset-failed "$name" 2>/dev/null || true

  binds=(
    --bind-ro=/nix/store
    # nix client -> the VM's daemon (untrusted), and the shared on-demand tools
    --bind=/nix/var/nix/daemon-socket
    --bind=/nix/var/nix/profiles/dev
    "--bind=${src//:/\\:}:/home/dev/${src##*/}"
    "--bind-ro=$dots:/home/dev/.dots"
    "--bind-ro=$dots/dot-config/zsh:/home/dev/.config/zsh"
    "--bind-ro=$dots/dot-config/nvim:/home/dev/.config/nvim"
    "--bind-ro=$dots/dot-config/starship:/home/dev/.config/starship"
    "--bind-ro=$dots/dot-config/lazygit:/home/dev/.config/lazygit"
    "--bind-ro=$dots/dot-agents:/home/dev/.agents"
  )
  # Caches, nvim plugins and agent logins: one copy shared by every container.
  for v in cache:.cache share:.local/share state:.local/state claude:.claude \
    codex:.codex gh:.config/gh go:go npm:.npm; do
    binds+=("--bind=$state/${v%%:*}:/home/dev/${v#*:}")
  done

  # Caps: a runaway in one container (a fork loop, a leak) hits its own OOM
  # killer and task limit instead of killing agents in every other one.
  systemd-run --quiet --unit="$name" --collect -p Delegate=yes \
    -p MemoryMax=75% -p TasksMax=4096 -- \
    systemd-nspawn --keep-unit --machine="$name" --directory="$template" \
    --ephemeral --boot --private-users=no "${binds[@]}"

  for _ in $(seq 90); do
    case $(systemctl --machine="$name" is-system-running 2>/dev/null || true) in
    running | degraded) break ;;
    esac
    sleep 1
  done
  running "$name" || { echo "vmdev: $name did not boot (journalctl -u $name)" >&2; exit 1; }
  if [[ -n ${6-} ]]; then
    # shellcheck disable=SC2016 # expanded by the container's sh
    systemd-run --quiet --machine="$name" --uid=501 --wait --pipe -E HOME=/home/dev -E PATH=/run/current-system/sw/bin -- \
      /run/current-system/sw/bin/sh -c 'git config --global user.name "$1"; git config --global user.email "$2"' _ "$6" "${7-}"
  fi
  ;;
stamp)
  echo "$2" >/var/lib/dev/stamp
  ;;
down)
  name=$2
  # With SRC, its project's container wins (NAME may belong to another one).
  if [[ -n ${3-} ]]; then
    found=$(by_src "$3")
    [[ -z $found ]] || name=$found
  fi
  running "$name" || { echo "vmdev: $2 is not running" >&2; exit 1; }
  machinectl poweroff "$name"
  # Agents can take a while to exit; past 90s, kill what's left.
  for _ in $(seq 90); do running "$name" || break; sleep 1; done
  running "$name" && machinectl terminate "$name" && sleep 2
  sweep
  ;;
ls)
  machinectl list --no-legend
  ;;
sessions)
  # Live zellij sessions per container: "CONTAINER SESSION [Created ...]".
  # (Exited ones are skipped: their resurrect files are shared via ~/.cache.)
  for m in $(machinectl list --no-legend | cut -d' ' -f1); do
    systemd-run --quiet --machine="$m" --uid=501 --wait --pipe -E HOME=/home/dev \
      -E PATH=/run/current-system/sw/bin -E XDG_RUNTIME_DIR=/run/user/501 -- /run/current-system/sw/bin/zellij list-sessions -n 2>/dev/null |
      grep -v EXITED | sed "s/^/$m /" || true
  done
  ;;
*)
  echo "usage: vmdev up NAME SRC DOTS STAMP [GIT_NAME GIT_EMAIL [TZ]] | stamp STAMP | down NAME [SRC] | ls | sessions" >&2
  exit 1
  ;;
esac
