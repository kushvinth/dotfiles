# Linux backend implementation for the `secret` CLI.
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
    runtimeInputs = [
      pkgs.coreutils
      pkgs.passage
    ];
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
      present() { passage show "dotfiles/$1" >/dev/null 2>&1; }
      value() { passage show "dotfiles/$(service "$1")" 2>/dev/null | head -1; }

      case "''${1:-list}" in
        list)
          printf '%-32s %-34s %s\n' VAR SERVICE PASSAGE
          for var in $(printf '%s\n' "''${!services[@]}" | sort); do
            if present "''${services[$var]}"; then state="set"; else state="MISSING"; fi
            printf '%-32s %-34s %s\n' "$var" "''${services[$var]}" "$state"
          done
          ;;
        set)
          [ $# -eq 2 ] || usage
          svc="$(service "$2")"
          echo "secret: storing $2 in passage 'dotfiles/$svc'" >&2
          passage insert -e "dotfiles/$svc"
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
          for var in "''${vars[@]}"; do
            val=$(value "$var") || exit $?
            export "$var=$val"
          done
          exec "$@"
          ;;
        env)
          shift
          [ $# -gt 0 ] || usage
          for var in "$@"; do
            val=$(value "$var") || exit $?
            printf 'export %s=%q\n' "$var" "$val"
          done
          ;;
        get)
          [ $# -eq 2 ] || usage
          value "$2"
          ;;
        rm)
          [ $# -eq 2 ] || usage
          svc="$(service "$2")"
          echo "secret: deleting $2 from passage" >&2
          passage rm -f "dotfiles/$svc"
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
