# macOS-specific checks contributed to `dotfiles-doctor`.
{
  config,
  lib,
  osConfig ? { },
  ...
}:
let
  agents = lib.mapAttrsToList (_: agent: {
    inherit (agent.serviceConfig) Label;
    alwaysOn = (agent.serviceConfig.KeepAlive or null) == true;
  }) (osConfig.launchd.user.agents or { });
in
{
  dotfiles.doctor.checks = {
    "darwin-launchd" = ''
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
      for log in "$HOME"/Library/Logs/{skhd,yabai,sketchybar}.err; do
        if [ -s "$log" ]; then warn "$log: $(tail -1 "$log")"; fi
      done
      # Secure input blinds skhd's event tap (and skhd won't start while it's on).
      si_pid="$(/usr/sbin/ioreg -l -w 0 | grep -o '"kCGSSessionSecureInputPID"=[0-9]*' | head -1 | cut -d= -f2)"
      if [ -n "$si_pid" ]; then
        warn "secure input on (held by $(/bin/ps -o comm= -p "$si_pid" 2>/dev/null || echo "pid $si_pid")): skhd hotkeys blocked until it clears"
      else
        ok "secure input off"
      fi
    '';

    "darwin-keychain" = ''
      echo "Keychain secrets"
      secret() { # <var> <service>
        if /usr/bin/security find-generic-password -a "$USER" -s "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1 missing (secret set $1)"; fi
      }
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          var: s: "secret ${lib.escapeShellArg var} ${lib.escapeShellArg s.service}"
        ) config.dotfiles.secrets
      )}
    '';

    "darwin-apps" = ''
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

      ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
      if [ -x "$ts" ]; then
        if "$ts" status >/dev/null 2>&1; then ok "Tailscale connected"; else warn "Tailscale: $("$ts" status 2>&1 | head -1)"; fi
      fi
    '';
  };
}
