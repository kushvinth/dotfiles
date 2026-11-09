# macOS Keychain backend implementation for the `secret` CLI.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.secrets;

  secret = pkgs.writeShellApplication {
    name = "secret";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      declare -A services=(
        ${lib.concatStringsSep "\n    " (
          lib.mapAttrsToList (var: s: "[${var}]=${lib.escapeShellArg s.service}") cfg
        )}
      )

      usage() {
        echo "usage: secret [list | set <VAR> | run <VAR>... -- <cmd> | load <VAR>... | get <VAR> | rm <VAR>]" >&2
        exit 2
      }
      service() {
        if [ -z "''${services[$1]:-}" ]; then
          echo "secret: $1 is not declared (nix/modules/home/common/secrets.nix); known: ''${!services[*]}" >&2
          exit 1
        fi
        echo "''${services[$1]}"
      }
      present() { /usr/bin/security find-generic-password -a "$USER" -s "$1" >/dev/null 2>&1; }
      value() { /usr/bin/security find-generic-password -a "$USER" -s "$(service "$1")" -w; }
      # Touch ID through sudo's PAM config (security.nix), password as fallback.
      # -k: ask every time, without using or refreshing sudo's cached login.
      auth() { /usr/bin/sudo -k -p "secret: password to read $* (or use Touch ID): " true; }

      case "''${1:-list}" in
        list)
          printf '%-32s %-34s %s\n' VAR SERVICE KEYCHAIN
          for var in $(printf '%s\n' "''${!services[@]}" | sort); do
            if present "''${services[$var]}"; then state="set"; else state="MISSING"; fi
            printf '%-32s %-34s %s\n' "$var" "''${services[$var]}" "$state"
          done
          ;;
        set)
          [ $# -eq 2 ] || usage
          svc="$(service "$2")"
          echo "secret: storing $2 in Keychain service '$svc' (input hidden)" >&2
          # -w last: security prompts for the value, so it never hits argv or history.
          /usr/bin/security add-generic-password -U -a "$USER" -s "$svc" -l "dotfiles: $2" -w
          ;;
        run)
          shift
          vars=()
          while [ $# -gt 0 ] && [ "$1" != "--" ]; do
            vars+=("$1")
            shift
          done
          [ $# -gt 1 ] && [ "$1" = "--" ] || usage
          shift
          [ ''${#vars[@]} -gt 0 ] || usage
          auth "''${vars[*]}" || exit $?
          for var in "''${vars[@]}"; do
            val=$(value "$var") || exit $?
            export "$var=$val"
          done
          exec "$@"
          ;;
        env)
          shift
          [ $# -gt 0 ] || usage
          auth "$*" || exit $?
          for var in "$@"; do
            val=$(value "$var") || exit $?
            printf 'export %s=%q\n' "$var" "$val"
          done
          ;;
        get)
          [ $# -eq 2 ] || usage
          auth "$2" || exit $?
          value "$2"
          ;;
        rm)
          [ $# -eq 2 ] || usage
          svc="$(service "$2")"
          echo "secret: deleting $2 (Keychain service '$svc')" >&2
          /usr/bin/security delete-generic-password -a "$USER" -s "$svc"
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  programs.secret.enable = lib.mkDefault true;
  programs.secret.package = secret;
}
