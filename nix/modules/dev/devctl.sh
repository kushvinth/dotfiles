# devctl: one vfkit microVM per project, behind `dev` (dot-config/zsh/.zshalias).
# Runs on the Mac as you. Every guest boots the same NixOS closure (guest.nix);
# only the arguments below differ per project. See nix/modules/dev/README.md.
#
#   devctl [enter] [--src DIR] [--branch NAME]   boot if needed, attach zellij
#   devctl start|stop|status|destroy|logs [--src DIR]
#   devctl ls                                    every project with state
#   devctl sessions                              live zellij sessions in running guests
#   devctl attach ID SESSION                     attach to a session in guest ID
#   devctl id [--src DIR]                        print the project's id

state_root=${DEVVM_STATE:-$HOME/.local/state/devvm}
dots_master=${DEVVM_DOTS:-$HOME/.local/share/devvm/dots}
dotfiles=${DEVVM_DOTFILES:-$HOME/dotfiles}
# KERNEL, INITRD, CMDLINE, STOREDISK (host-darwin.nix, built from guest.nix).
guest_env=${DEVVM_GUEST_ENV:-/etc/devvm/guest.env}
# Root-owned, rewritten every 30 s by the devvm-pf launchd daemon.
# devctl can't query pf without root, so it trusts this file for 90 s: pf
# turned off behind the daemon's back stays off at most that long (the daemon
# turns it back on at its next run).
pf_status=/var/run/devvm-pf.status
key=$state_root/ssh/id_ed25519
cpus=${DEVVM_CPUS:-4}
mem=${DEVVM_MEM:-4096}
disk_size=24G
timesync_port=1024 # guest.nix timesyncPort
# What the guest gets of the dotfiles: git-tracked files under these paths.
# Never nix/ (secrets.nix declares the Keychain names) or .zsh_history.
dot_paths=(dot-config/zsh dot-config/claude dot-config/nvim dot-config/starship
  dot-config/lazygit dot-config/opencode dot-agents)

die() {
  printf 'devctl: %s\n' "$*" >&2
  exit 1
}
say() { printf '\033[34mdev❯\033[0m %s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: devctl [enter] [--src DIR] [--branch NAME]   boot if needed, attach zellij
       devctl start|stop|status|destroy|logs [--src DIR]
       devctl forward [--src DIR] [LOCAL:]PORT...      guest port -> localhost (background)
       devctl forward [--src DIR] -d [PORT...]         stop forwards (all without PORT)
       devctl ls | sessions | attach ID SESSION | run ID CMD | id [--src DIR]
EOF
  exit 2
}

# --- identity -----------------------------------------------------------------

canon() { (cd "$1" 2>/dev/null && pwd -P) || die "$1: no such directory"; }

# dev-<basename, sanitised, max 40>-<first 8 hex of sha256(canonical path)>:
# deterministic, no lookup, and two projects with the same name don't collide.
id_for() {
  local base=${1##*/} h
  base=${base//[^A-Za-z0-9-]/-}
  h=$(printf %s "$1" | sha256sum | cut -c1-8)
  printf 'dev-%s-%s\n' "${base:0:40}" "$h"
}

# Locally administered unicast MAC from the id, stable across boots.
mac_for() {
  local h
  h=$(printf %s "$1" | sha256sum)
  printf '02:%s:%s:%s:%s:%s\n' "${h:0:2}" "${h:2:2}" "${h:4:2}" "${h:6:2}" "${h:8:2}"
}

# Sets src, id, dir from --src (default: $PWD's git root, or $PWD).
resolve() {
  local s=${1:-}
  if [[ -z $s ]]; then
    s=$(git rev-parse --show-toplevel 2>/dev/null) || s=$PWD
  fi
  src=$(canon "$s")
  [[ $src != "$HOME" && $src != / ]] || die "refusing to share $src with a VM; cd into a project first"
  # vfkit splits device options on commas; a quote would end the cmdline.
  [[ $src != *[,\"]* ]] || die "$src contains a comma or quote, which vfkit can't pass; rename or symlink it"
  id=$(id_for "$src")
  dir=$state_root/$id
}

# Never hand a guest the Mac's own control plane: the dotfiles checkout (its
# .git/hooks, scripts and nix config run on the Mac), keys, or devctl's
# state. Refused if src is, is inside, or contains one of these. Only for
# booting: stop/status/destroy still work on a VM made before this check.
protect_check() {
  local p
  for p in "$dotfiles" "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.config" "$HOME/Library" "$state_root" "${dots_master%/dots}"; do
    [[ -e $p ]] || continue
    p=$(canon "$p")
    if [[ $src == "$p" || $src == "$p"/* || $p == "$src"/* ]]; then
      die "refusing to boot a VM on $src: it is or holds $p, which the Mac runs or trusts. Use a separate project directory (stop or destroy an existing one with dev stop / dev destroy)"
    fi
  done
}

# --- state --------------------------------------------------------------------

vm_pid() {
  local p
  p=$(cat "$dir/pid" 2>/dev/null) || return 1
  [[ $p =~ ^[0-9]+$ ]] && kill -0 "$p" 2>/dev/null &&
    [[ $(ps -p "$p" -o comm= 2>/dev/null) == *vfkit* ]] && echo "$p"
}

lockdir=
unlock() { [[ -z $lockdir ]] || rm -rf "$lockdir"; lockdir=; }
trap unlock EXIT
# mkdir is atomic: one devctl per project boots or stops it at a time. A lock
# whose holder died is broken; a live one is waited for (two `dev` at once).
lock() {
  local d=$dir/lock holder i=0
  while ! mkdir "$d" 2>/dev/null; do
    holder=$(cat "$d/pid" 2>/dev/null || true)
    if [[ -n $holder ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$d"
      continue
    fi
    ((i++ == 0)) && say "waiting for another devctl on $id (pid ${holder:-?})"
    ((i < 120)) || die "$d is still held (pid ${holder:-?}); if no devctl runs, rm -r '$d' and retry"
    sleep 1
  done
  lockdir=$d
  echo $$ >"$d/pid"
}

clean_stale() {
  vm_pid >/dev/null && return
  kill_forwards
  rm -f "$dir/pid" "$dir/rest.sock" "$dir/vsock-ssh.sock"
}

# `dev forward`: one background `ssh -N -L` per local port, pid in forward/.
# Each keeps an SSH session open, so the guest's idle auto-stop leaves it up.
forward_pid() {
  local f=$dir/forward/$1.pid p
  { read -r p _ <"$f"; } 2>/dev/null || return 1
  kill -0 "$p" 2>/dev/null && [[ $(ps -p "$p" -o comm= 2>/dev/null) == *ssh* ]] && echo "$p"
}
kill_forwards() {
  local f l p
  for f in "$dir"/forward/*.pid; do
    [[ -e $f ]] || continue
    l=${f##*/}
    l=${l%.pid}
    if [[ -z ${1-} || $1 == "$l" ]]; then
      p=$(forward_pid "$l") && kill "$p" 2>/dev/null
      rm -f "$f" "$dir/forward/$l.log"
    fi
  done
}
list_forwards() {
  local f l g p
  for f in "$dir"/forward/*.pid; do
    [[ -e $f ]] || continue
    l=${f##*/}
    l=${l%.pid}
    read -r _ g <"$f" || true
    if p=$(forward_pid "$l"); then
      printf '  http://localhost:%s -> guest port %s (pid %s)\n' "$l" "$g" "$p"
    else
      rm -f "$f"
    fi
  done
}

# The guest this VM booted vs the one darwin-rebuild installed since.
outdated() {
  [[ $(readlink -f "$guest_env" 2>/dev/null) != "$(cat "$dir/booted" 2>/dev/null)" ]]
}

ask() {
  local ans
  printf '\033[34mdev❯\033[0m %s [y/N] ' "$1" >&2
  read -r ans </dev/tty || ans=''
  [[ $ans == [yY]* ]]
}

# The Mac-side network wall must be up before any guest boots (fail closed).
pf_check() {
  local why=
  if [[ ! -f $pf_status ]]; then
    why="$pf_status is missing"
  elif [[ $(stat -c %u "$pf_status") != 0 ]]; then
    why="$pf_status is not owned by root"
  elif (($(date +%s) - $(stat -c %Y "$pf_status") > 90)); then
    why="$pf_status is older than 90 seconds (the daemon stopped refreshing it)"
  elif [[ $(head -c 6 "$pf_status") != loaded ]]; then
    why="the daemon reports: $(head -n1 "$pf_status")"
  fi
  [[ -z $why ]] && return
  printf 'devctl: the pf anchor that keeps VMs off your LAN, Tailscale and the Mac is not loaded: %s.\n' "$why" >&2
  printf '  Fix: sudo launchctl kickstart -k system/org.nixos.devvm-pf  (logs: /var/log/devvm-pf.log)\n' >&2
  printf '  If that fails, darwin-rebuild switch; macOS updates can reset pf.\n' >&2
  exit 1
}

# --- dotfiles -----------------------------------------------------------------

# Git-tracked files only, refreshed when a tracked path, mtime or size changed;
# files no longer tracked are removed. Moved here from the old `dev` (.zshalias).
export_dots() {
  [[ -e $dotfiles/.git ]] || die "$dotfiles is not a git checkout; clone your dotfiles there (or set DEVVM_DOTFILES)"
  mkdir -p "$dots_master"
  local stamp old=
  stamp=$(git -C "$dotfiles" ls-files -z --recurse-submodules -- "${dot_paths[@]}" |
    (cd "$dotfiles" && xargs -0 stat -c '%n %Y %s' 2>/dev/null) | sha256sum | cut -c1-12)
  [[ -r $dots_master/.stamp ]] && old=$(<"$dots_master/.stamp")
  [[ $stamp == "$old" ]] && return
  comm -23 <(cd "$dots_master" && find . -type f ! -name .stamp | sed 's|^\./||' | sort) \
    <(git -C "$dotfiles" ls-files --recurse-submodules -- "${dot_paths[@]}" | sort) |
    (cd "$dots_master" && xargs -r -d '\n' rm -f --)
  local rc=0
  git -C "$dotfiles" ls-files -z --recurse-submodules -- "${dot_paths[@]}" |
    rsync -a --from0 --files-from=- "$dotfiles/" "$dots_master/" 2>/dev/null || rc=$?
  # 23: a listed file is gone (deleted, not yet staged); the rest copied.
  if ((rc == 0 || rc == 23)); then
    printf '%s\n' "$stamp" >"$dots_master/.stamp"
  else
    die "copying dotfiles to $dots_master failed (rsync $rc)"
  fi
}

# vfkit can't make a share read-only, so each launch gets its own clone
# (APFS clonefile: instant, no space) of the export: a guest can only spoil
# its own copy, and that is replaced at the next boot.
fresh_dots() {
  if [[ -e $dir/dots ]]; then
    chmod -R u+w "$dir/dots" 2>/dev/null || true
    rm -rf "$dir/dots"
  fi
  /bin/cp -c -R "$dots_master" "$dir/dots" 2>/dev/null || /bin/cp -R "$dots_master" "$dir/dots"
}

# --- VM -----------------------------------------------------------------------

load_guest_env() {
  [[ -r $guest_env ]] || die "$guest_env is missing: darwin-rebuild switch (nix/modules/dev/host-darwin.nix) installs it"
  KERNEL='' INITRD='' CMDLINE='' STOREDISK=''
  # shellcheck source=/dev/null
  . "$guest_env"
  local f
  for f in "$KERNEL" "$INITRD" "$STOREDISK"; do
    [[ -r $f ]] || die "guest artefact $f is missing; darwin-rebuild switch rebuilds it"
  done
}

boot() {
  load_guest_env
  [[ -r $key ]] || die "$key is missing. Create it: ssh-keygen -t ed25519 -N '' -f $key, copy $key.pub to nix/modules/dev/devvm_ssh.pub in ~/dotfiles, then darwin-rebuild switch"
  mkdir -p "$dir/exchange"
  if [[ ! -e $dir/persist.img ]]; then
    say "first boot of $id: creating a sparse $disk_size volume (formatted inside the VM)"
    truncate -s "$disk_size" "$dir/persist.img"
  fi
  export_dots
  fresh_dots
  printf '%s\n' "$src" >"$dir/src"
  : >"$dir/console.log"
  local mac
  mac=$(mac_for "$id")
  # Disk order matters: vda = store image, vdb = /persist (guest.nix).
  local -a args=(
    --cpus "$cpus" --memory "$mem"
    --bootloader "linux,kernel=$KERNEL,initrd=$INITRD,cmdline=\"console=hvc0 reboot=t panic=-1 $CMDLINE\""
    --device virtio-rng
    --device "virtio-serial,logFilePath=$dir/console.log"
    --device "virtio-blk,path=$STOREDISK,readonly"
    --device "virtio-blk,path=$dir/persist.img"
    --device "virtio-fs,sharedDir=$src,mountTag=workspace"
    --device "virtio-fs,sharedDir=$dir/dots,mountTag=dots"
    --device "virtio-fs,sharedDir=$dir/exchange,mountTag=exchange"
    --device "virtio-vsock,port=22,socketURL=$dir/vsock-ssh.sock,connect"
    --device "virtio-net,nat,mac=$mac"
    --restful-uri "unix://$dir/rest.sock"
    --timesync "vsockPort=$timesync_port"
  )
  # Job control: vfkit gets its own process group, so Ctrl-C here (or in the
  # terminal later) doesn't reach it.
  set -m
  nohup vfkit "${args[@]}" >"$dir/vfkit.log" 2>&1 </dev/null &
  local pid=$!
  set +m
  echo "$pid" >"$dir/pid"
  readlink -f "$guest_env" >"$dir/booted"
  sleep 0.5
  kill -0 "$pid" 2>/dev/null || die "vfkit exited at once: $(tail -n 5 "$dir/vfkit.log")"
}

ssh_opts() {
  # -F /dev/null: none of ~/.ssh/config (agent forwarding, Include, ...) applies.
  # Port forwarding only for `dev forward` (Mac -> guest; the guest's sshd
  # allows nothing the other way).
  local clear=yes
  [[ ${1-} == fwd ]] && clear=no
  printf '%s\0' -F /dev/null -i "$key" -o IdentitiesOnly=yes -o IdentityAgent=none \
    -o ForwardAgent=no -o ForwardX11=no -o "ClearAllForwardings=$clear" \
    -o "ProxyCommand=socat - 'UNIX-CONNECT:$dir/vsock-ssh.sock'" \
    -o "UserKnownHostsFile=$dir/known_hosts" -o StrictHostKeyChecking=accept-new \
    -o "HostKeyAlias=$id" -o LogLevel=ERROR -o ServerAliveInterval=30
}

guest_ssh() {
  local -a o
  mapfile -d '' o < <(ssh_opts)
  # shellcheck disable=SC2029 # callers quote the remote command themselves
  ssh "${o[@]}" "$@"
}

wait_ssh() {
  local i
  for ((i = 0; i < 90; i++)); do
    [[ -S $dir/vsock-ssh.sock ]] &&
      guest_ssh -o BatchMode=yes -o ConnectTimeout=3 dev@guest true 2>/dev/null && return
    vm_pid >/dev/null || die "the VM stopped while booting; see: devctl logs --src '$src' (and $dir/vfkit.log)"
    sleep 1
  done
  die "no SSH from $id after 90s; see: devctl logs --src '$src'. To retry: devctl stop --src '$src' && dev"
}

rest() {
  curl -sS --max-time 5 --unix-socket "$dir/rest.sock" "$@"
}

vm_state() {
  rest http://localhost/vm/state 2>/dev/null | sed -n 's/.*"state" *: *"\([A-Za-z]*\)".*/\1/p'
}

stop_vm() {
  local pid i
  pid=$(vm_pid) || {
    clean_stale
    return 0
  }
  say "stopping $id"
  kill_forwards
  rest -X POST -d '{"state":"Stop"}' http://localhost/vm/state >/dev/null 2>&1 || true
  for ((i = 0; i < 60; i++)); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    say "$id did not shut down in 60s; hard stop"
    rest -X POST -d '{"state":"HardStop"}' http://localhost/vm/state >/dev/null 2>&1 || true
    sleep 3
    kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
    sleep 1
  fi
  clean_stale
}

guest_ip() {
  local mac ip
  # vmnet's DHCP server keys leases by client id ("1,<mac>", unpadded octets;
  # the guest sends its MAC, guest.nix). Last match wins (newest lease).
  mac=$(mac_for "$id" | sed -E 's/(^|:)0([0-9a-f])/\1\2/g')
  ip=$(awk -v m="1,$mac" '/^\{/ { ip = "" } $1 ~ /^ip_address=/ { sub(/.*=/, "", $1); ip = $1 }
    $1 ~ /^(hw_address|identifier)=/ { sub(/[^=]*=/, "", $1); if ($1 == m) found = ip } END { if (found) print found }' \
    /var/db/dhcpd_leases 2>/dev/null || true)
  # Guests booted before that fix: ask the guest itself.
  [[ -n $ip ]] || ip=$(guest_ssh -o BatchMode=yes -o ConnectTimeout=3 dev@guest \
    "ip -4 -o addr show scope global | awk '{ sub(/\\/.*/, \"\", \$4); print \$4; exit }'" 2>/dev/null || true)
  printf '%s\n' "${ip:-?}"
}

# .git/config and .git/hooks as the guest left them: git on the Mac would run
# hooks, fsmonitor, filters and pagers from there.
git_fp() {
  [[ -d $src/.git ]] || return 0
  { cat "$src/.git/config" 2>/dev/null; find "$src/.git/hooks" -type f -exec sha256sum {} + 2>/dev/null | sort; } | sha256sum | cut -c1-16
}
git_warn() {
  local now old
  now=$(git_fp)
  old=$(cat "$dir/git.fp" 2>/dev/null || true)
  if [[ -n $old && $now != "$old" ]]; then
    say "WARNING: .git/config or .git/hooks in $src changed since the last check."
    say "  A guest can plant hooks, filters, core.pager or core.sshCommand there. Review before using git on the Mac:"
    say "  git -C '$src' config --local --list; ls -la '$src/.git/hooks'"
  fi
  printf '%s\n' "$now" >"$dir/git.fp"
}

# --- commands -----------------------------------------------------------------

cmd=enter
case ${1:-} in
enter | start | stop | status | destroy | logs | ls | sessions | attach | run | id | forward)
  cmd=$1
  shift
  ;;
-h | --help | help) usage ;;
esac

opt_src='' opt_branch=''
pos=()
while (($#)); do
  case $1 in
  --src)
    opt_src=${2:?--src needs a directory}
    shift 2
    ;;
  --branch)
    opt_branch=${2-}
    shift 2
    ;;
  -h | --help) usage ;;
  *)
    pos+=("$1")
    shift
    ;;
  esac
done

# `devctl attach ID SESSION` / `ls` / `sessions` take an id, not a source.
with_id() {
  [[ $1 =~ ^dev-[A-Za-z0-9-]+$ && -d $state_root/$1 ]] || die "no such VM: $1 (devctl ls)"
  id=$1 dir=$state_root/$1
  src=$(cat "$dir/src" 2>/dev/null || true)
}

case $cmd in
id)
  resolve "$opt_src"
  echo "$id"
  ;;

enter | start)
  resolve "$opt_src"
  protect_check
  pf_check # before anything is created: a refused boot leaves no state
  mkdir -p "$dir"
  chmod 700 "$state_root" "$dir"
  lock
  clean_stale
  if vm_pid >/dev/null && outdated; then
    if [[ $cmd == enter && -t 0 ]] &&
      ask "$id runs the guest from before your last darwin-rebuild. Restart it now (stops what runs in it)?"; then
      stop_vm
    else
      say "$id runs an older guest; dev stop && dev to update it"
    fi
  fi
  if ! vm_pid >/dev/null; then
    say "booting $id"
    boot
  fi
  unlock
  wait_ssh
  if [[ $cmd == start ]]; then
    say "$id is running; attach with: dev"
    exit 0
  fi
  git_warn
  br=$opt_branch
  [[ -n $br ]] || br=$(git -C "$src" branch --show-current 2>/dev/null || true)
  session="${src##*/}${br:+@${br//\//-}}"
  tz=$(readlink /etc/localtime 2>/dev/null || true)
  tz=${tz#*/zoneinfo/}
  q() { printf '"%s"' "${1//\"/}"; }
  setenv="COLORTERM=${COLORTERM:-truecolor}"
  [[ -n $tz ]] && setenv+=" TZ=$tz"
  if gname=$(git config user.name 2>/dev/null) && [[ -n $gname ]]; then
    setenv+=" GIT_AUTHOR_NAME=$(q "$gname") GIT_COMMITTER_NAME=$(q "$gname")"
  fi
  if gmail=$(git config user.email 2>/dev/null) && [[ -n $gmail ]]; then
    setenv+=" GIT_AUTHOR_EMAIL=$(q "$gmail") GIT_COMMITTER_EMAIL=$(q "$gmail")"
  fi
  # No onboarding: the agents (claude, opencode, codex, ...) are installed;
  # sign in inside the guest when you want one. Logins stay on /persist.
  # shellcheck disable=SC2016 # expanded by the guest's shell
  # dev-session-init (guest): git identity from GIT_AUTHOR_*, Claude settings
  # and trust. Missing on guests booted before it existed.
  remote='command -v dev-session-init >/dev/null 2>&1 && dev-session-init
cd /workspace || exit 1
exec zellij attach -c "$1"'
  rc=0
  guest_ssh -t -o "SetEnv=$setenv" dev@guest "sh -c $(printf %q "$remote") _ $(printf %q "$session")" || rc=$?
  git_warn
  exit "$rc"
  ;;

stop)
  resolve "$opt_src"
  [[ -d $dir ]] || die "$src has no VM (devctl ls)"
  lock
  stop_vm
  ;;

status)
  resolve "$opt_src"
  [[ -d $dir ]] || {
    echo "$id: no VM yet (dev creates it)"
    exit 0
  }
  if pid=$(vm_pid); then
    printf '%s: %s, pid %s, ip %s\n  src %s\n' "$id" "$(vm_state || echo unknown)" "$pid" "$(guest_ip)" "$src"
  else
    printf '%s: stopped\n  src %s\n' "$id" "$src"
  fi
  printf '  state %s (%s)\n' "$dir" "$(du -sh "$dir" 2>/dev/null | cut -f1)"
  outdated && vm_pid >/dev/null && echo "  runs an older guest: dev stop && dev to update"
  list_forwards
  ;;

destroy)
  resolve "$opt_src"
  [[ -d $dir ]] || die "$src has no VM (devctl ls)"
  printf 'devctl: delete %s and everything in it (its /persist: logins, caches, history)? [y/N] ' "$dir" >&2
  read -r ans </dev/tty || ans=
  [[ $ans == [yY]* ]] || die "kept $dir"
  lock
  stop_vm
  unlock
  chmod -R u+w "$dir" 2>/dev/null || true
  rm -rf "$dir"
  say "destroyed $id"
  ;;

logs)
  resolve "$opt_src"
  [[ -r $dir/console.log ]] || die "no console log for $id yet"
  exec tail -n 200 -f "$dir/console.log"
  ;;

ls)
  shopt -s nullglob
  printf '%-56s %-8s %s\n' ID STATE SOURCE
  for d in "$state_root"/dev-*/; do
    d=${d%/}
    id=${d##*/} dir=$d
    st=stopped
    vm_pid >/dev/null && st=running
    printf '%-56s %-8s %s\n' "$id" "$st" "$(cat "$d/src" 2>/dev/null || echo '?')"
  done
  ;;

sessions)
  # "ID SESSION [Created ...]" per live zellij session in each running guest.
  shopt -s nullglob
  for d in "$state_root"/dev-*/; do
    d=${d%/}
    id=${d##*/} dir=$d
    vm_pid >/dev/null || continue
    guest_ssh -o BatchMode=yes -o ConnectTimeout=3 dev@guest 'zellij list-sessions -n 2>/dev/null' 2>/dev/null |
      grep -v EXITED | sed "s/^/$id /" || true
  done
  ;;

forward)
  resolve "$opt_src"
  if [[ ! -d $dir ]] || ! vm_pid >/dev/null; then die "$id is not running; start it first: dev (or dev start)"; fi
  mkdir -p "$dir/forward"
  if ((${#pos[@]} == 0)); then
    list_forwards
    exit 0
  fi
  if [[ ${pos[0]} == -d || ${pos[0]} == --stop ]]; then
    if ((${#pos[@]} == 1)); then
      kill_forwards
    else
      for l in "${pos[@]:1}"; do kill_forwards "$l"; done
    fi
    exit 0
  fi
  mapfile -d '' fo < <(ssh_opts fwd)
  for spec in "${pos[@]}"; do
    [[ $spec =~ ^(([0-9]+):)?([0-9]+)$ ]] ||
      die "bad port '$spec'. Usage: dev forward [LOCAL:]PORT ... | dev forward -d [PORT ...]"
    g=${BASH_REMATCH[3]} l=${BASH_REMATCH[2]:-${BASH_REMATCH[3]}}
    if p=$(forward_pid "$l"); then
      say "localhost:$l is already forwarded (pid $p)"
      continue
    fi
    set -m
    nohup ssh "${fo[@]}" -N -o ExitOnForwardFailure=yes -L "127.0.0.1:$l:127.0.0.1:$g" dev@guest \
      >"$dir/forward/$l.log" 2>&1 </dev/null &
    p=$!
    set +m
    echo "$p $g" >"$dir/forward/$l.pid"
    sleep 1.5
    if forward_pid "$l" >/dev/null; then
      say "http://localhost:$l -> $id port $g (stop: dev forward -d $l)"
    else
      msg=$(tail -n 2 "$dir/forward/$l.log" 2>/dev/null || true)
      rm -f "$dir/forward/$l.pid"
      die "forwarding localhost:$l failed: ${msg:-ssh exited}. Port taken on the Mac? Try: dev forward 18$g:$g"
    fi
  done
  ;;

run)
  # Non-interactive command in a running guest, as dev (CMD goes to its shell).
  ((${#pos[@]} >= 2)) || die "usage: devctl run ID CMD"
  with_id "${pos[0]}"
  vm_pid >/dev/null || die "$id is not running (dev, in $src)"
  guest_ssh -o BatchMode=yes dev@guest "${pos[*]:1}"
  ;;

attach)
  ((${#pos[@]} == 2)) || die "usage: devctl attach ID SESSION"
  with_id "${pos[0]}"
  vm_pid >/dev/null || die "$id is not running (dev, in $src)"
  guest_ssh -t -o "SetEnv=COLORTERM=${COLORTERM:-truecolor}" dev@guest \
    "cd /workspace && exec zellij attach $(printf %q "${pos[1]}")"
  ;;
esac
