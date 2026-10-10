# Read-only health check, run last on every switch. It only reports, never
# fails the switch. Launchd agents were just reloaded, so one that is still
# starting can show up as not running.
{
  config,
  lib,
  pkgs,
  osConfig,
  inputs,
  ...
}:
let
  # KeepAlive = true: should be running. Periodic or on-demand jobs (borgmatic,
  # whisper-server, ...) only have to have exited cleanly.
  agents = lib.mapAttrsToList (_: agent: {
    inherit (agent.serviceConfig) Label;
    alwaysOn = (agent.serviceConfig.KeepAlive or null) == true;
  }) osConfig.launchd.user.agents;

  # dot-config/zsh/keychain-env: `ENV_VAR  keychain-service` per line.
  secrets = lib.concatMap (
    line:
    let
      m = builtins.match "([A-Za-z_][A-Za-z0-9_]*)[[:space:]]+([^[:space:]]+).*" line;
    in
    lib.optional (m != null) {
      var = lib.elemAt m 0;
      service = lib.elemAt m 1;
    }
  ) (lib.splitString "\n" (builtins.readFile "${inputs.self}/../dot-config/zsh/keychain-env"));

  doctor = pkgs.writeShellApplication {
    name = "dotfiles-doctor";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
    ];
    # No errexit: a failing check is a finding, not a reason to stop.
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = ''
      problems=0
      ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
      warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
      bad() {
        printf '  \033[31m✗\033[0m %s\n' "$*"
        problems=$((problems + 1))
      }

      echo "Links into ${config.dotfiles.repoRoot}"
      missing=0
      for path in ${lib.escapeShellArgs (lib.attrValues config.dotfiles.links)}; do
        if [ ! -e "$path" ]; then
          bad "missing: $path"
          missing=1
        fi
      done
      [ "$missing" = 1 ] || ok "${toString (lib.length (lib.attrNames config.dotfiles.links))} links resolve"

      echo "PATH (fresh login shell)"
      for cmd in git curl python3 tsui yabai brew; do
        resolved="$(env -i HOME="$HOME" USER="$USER" TERM=dumb /bin/zsh -lc "whence -p $cmd" 2>/dev/null)"
        case "$resolved" in
          /run/current-system/* | /etc/profiles/* | /nix/* | /opt/homebrew/*) ok "$cmd → $resolved" ;;
          "") bad "$cmd not found" ;;
          *) bad "$cmd → $resolved (expected nix/Homebrew; check /etc/zshenv)" ;;
        esac
      done

      echo "launchd agents"
      agent() { # <label> <always on: 1|0>
        local info state last
        info="$(/bin/launchctl print "gui/$(id -u)/$1" 2>/dev/null)"
        if [ -z "$info" ]; then
          bad "$1 not loaded"
          return
        fi
        state="$(awk -F' = ' '/^\tstate = / { print $2; exit }' <<<"$info")"
        last="$(awk -F' = ' '/last exit code/ { print $2; exit }' <<<"$info")"
        if [ "$2" = 1 ]; then
          if [ "$state" = running ]; then ok "$1 running"; else bad "$1 $state (last exit: $last)"; fi
        else
          case "$last" in
            0 | 75 | "(never exited)" | "") ok "$1 (last exit: ''${last:-none})" ;;
            *) bad "$1 last exit $last" ;;
          esac
        fi
      }
      ${lib.concatMapStringsSep "\n" (
        a: "agent ${lib.escapeShellArg a.Label} ${if a.alwaysOn then "1" else "0"}"
      ) agents}
      for log in /tmp/skhd.err /tmp/yabai.err /tmp/sketchybar.err; do
        if [ -s "$log" ]; then warn "$log: $(tail -1 "$log")"; fi
      done
      # Secure input blinds skhd's event tap (and skhd won't start while it's on).
      si_pid="$(/usr/sbin/ioreg -l -w 0 | grep -o '"kCGSSessionSecureInputPID"=[0-9]*' | head -1 | cut -d= -f2)"
      if [ -n "$si_pid" ]; then
        warn "secure input on (held by $(/bin/ps -o comm= -p "$si_pid" 2>/dev/null || echo "pid $si_pid")): skhd hotkeys blocked until it clears"
      else
        ok "secure input off"
      fi

      echo "Keychain secrets (dot-config/zsh/keychain-env)"
      secret() { # <var> <service>
        if /usr/bin/security find-generic-password -a "$USER" -s "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1 missing (secret set $1)"; fi
      }
      ${lib.concatMapStringsSep "\n" (
        s: "secret ${lib.escapeShellArg s.var} ${lib.escapeShellArg s.service}"
      ) secrets}

      echo "Apps"
      dups=0
      for app in "/Applications/Nix Apps/"*.app; do
        [ -e "$app" ] || continue
        name="$(basename "$app")"
        if [ -e "/Applications/$name" ] && [ ! -L "/Applications/$name" ]; then
          bad "$name in both /Applications and /Applications/Nix Apps"
          dups=1
        fi
      done
      [ "$dups" = 1 ] || ok "no duplicate nix/standalone apps"
      for f in /etc/paths.d/*; do
        entry="$(basename "$f")"
        [ "$entry" = 10-cryptex ] && continue
        while IFS= read -r dir; do
          if [ -n "$dir" ] && [ ! -e "$dir" ]; then warn "/etc/paths.d/$entry → missing $dir"; fi
        done <"$f"
      done

      echo "Updates"
      age=$((($(date +%s) - ${toString inputs.nixpkgs.lastModified}) / 86400))
      if [ "$age" -le 30 ]; then ok "nixpkgs pinned $age days ago"; else warn "nixpkgs pinned $age days ago (darnix --update)"; fi
      ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
      if [ -x "$ts" ]; then
        if "$ts" status >/dev/null 2>&1; then ok "Tailscale connected"; else warn "Tailscale: $("$ts" status 2>&1 | head -1)"; fi
      fi

      echo
      if [ "$problems" -eq 0 ]; then
        echo "doctor: all core checks passed"
      else
        echo "doctor: $problems problem(s) found"
      fi
    '';
  };
in
{
  home.activation.dotfilesDoctor = lib.hm.dag.entryAfter [
    "dotfilesBatCache"
    "dotfilesNvimPlugins"
    "dotfilesAppStore"
  ] "${lib.getExe doctor}";
}
