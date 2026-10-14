# Secrets: values live in the macOS login Keychain (never in git or the nix
# store); which ones exist, and which commands get them, is declared here.
# Nothing is exported at shell start: `secret run`, and the command aliases
# generated below, ask for Touch ID (or your password) on every use.
#
#   secret                         list, and whether each value is in the Keychain
#   secret set <VAR>               store or replace a value (asked for, hidden)
#   secret run <VAR>... -- <cmd>   the vars exist only for that command
#   secret load <VAR>...           export into this shell (zsh; `unset` when done)
#   secret get <VAR>               print the value
#   secret rm <VAR>                delete the Keychain item
#   use secret <VAR>...            in a project's .envrc: set while you're in
#                                  that directory (direnv helper, darwin/system.nix)
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
          echo "secret: $1 is not declared (nix/modules/home/secrets.nix); known: ''${!services[*]}" >&2
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
          while [ $# -gt 0 ] && [ "$1" != -- ]; do
            service "$1" >/dev/null
            vars+=("$1")
            shift
          done
          [ $# -ge 2 ] && [ ''${#vars[@]} -gt 0 ] || usage
          shift
          auth "''${vars[@]}"
          for var in "''${vars[@]}"; do
            val="$(value "$var")"
            export "$var=$val"
          done
          exec "$@"
          ;;
        env) # for the zsh `secret load` wrapper: prints `export VAR=...` lines
          shift
          [ $# -gt 0 ] || usage
          for var; do service "$var" >/dev/null; done
          auth "$@"
          for var; do
            val="$(value "$var")"
            printf 'export %s=%q\n' "$var" "$val"
          done
          ;;
        get)
          [ $# -eq 2 ] || usage
          service "$2" >/dev/null
          auth "$2"
          value "$2"
          ;;
        rm)
          [ $# -eq 2 ] || usage
          /usr/bin/security delete-generic-password -a "$USER" -s "$(service "$2")" >/dev/null
          echo "secret: deleted the Keychain item for $2 (it stays declared in nix)" >&2
          ;;
        *) usage ;;
      esac
    '';
  };

  # command → the vars it gets, e.g. { borg = [ "BORG_PASSPHRASE" ]; }
  commands = lib.zipAttrs (
    lib.concatLists (lib.mapAttrsToList (var: s: map (c: { ${c} = var; }) s.commands) cfg)
  );
in
{
  options.dotfiles.secrets = lib.mkOption {
    description = "Env vars whose values live in the macOS login Keychain.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          service = lib.mkOption {
            type = lib.types.str;
            description = "Keychain item (service name) holding the value.";
          };
          commands = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Interactive commands aliased to `secret run <VAR> -- <command>`.";
          };
        };
      }
    );
    default = { };
  };

  config = {
    dotfiles.secrets = {
      # Also read by the scheduled backup itself (encryption_passcommand in
      # assets/configs/etc/borgmatic/config.yaml), which needs no prompt.
      BORG_PASSPHRASE = {
        service = "borg-xteink";
        commands = [ "borg" ];
      };
      # opencode's GitHub MCP reads it at startup (dot-config/opencode/opencode.jsonc).
      GITHUB_PERSONAL_ACCESS_TOKEN = {
        service = "github-personal-access-token";
        commands = [ "opencode" ];
      };
      DEEPSEEK_API_KEY.service = "deepseek-api-key";
      # From `claude setup-token`. No `claude` alias: when set, it overrides your
      # normal Claude Code login, so pass it only where needed (CI, scripts).
      CLAUDE_CODE_OAUTH_TOKEN.service = "claude-code-oauth-token";
      # Agent-finished notifications: ~/.agents/bin/notify.sh POSTs to Gotify.
      # `hydrate` runs at Claude Code session start and caches these so later
      # sends never prompt; the URL is a secret var only so the host stays out
      # of the public repo.
      GOTIFY_URL.service = "gotify-url";
      GOTIFY_TOKEN.service = "gotify-token";

      # Migrated off plaintext files (2026-10-11). Values live in the login
      # Keychain; the files they used to sit in are stripped (see docs/secrets.md).
      EXPLABS_API_KEY.service = "explabs-api-key"; # was exported by ~/.zshrc
      OPENAI_API_KEY.service = "openai-api-key"; # was inline in shell history
      ELEVENLABS_API_KEY.service = "elevenlabs-api-key"; # was inline in shell history
      WAKAPI_API_KEY.service = "wakapi-api-key"; # was in ~/.wakatime.cfg
      HEROKU_API_KEY = {
        service = "heroku-api-key"; # was in ~/.netrc
        commands = [ "heroku" ];
      };
      RCLONE_CONFIG_STORAGEBOX_PASS = {
        service = "rclone-storagebox"; # was in ~/.config/rclone/rclone.conf
        commands = [ "rclone" ];
      };
    };

    home.packages = [ secret ];

    # Sourced by .zshrc: `secret load` (a binary can't export into your shell)
    # and the command aliases. Aliases only apply to interactive shells, so
    # scripts and launchd jobs (borgmatic) call the real binaries.
    xdg.dataFile."dotfiles/secrets.zsh".text = ''
      # Generated by nix/modules/home/secrets.nix
      secret() {
        if [[ $1 == load ]]; then
          shift
          local exports
          exports=$(command secret env "$@") || return
          eval "$exports"
          print -u2 "secret: exported $* into this shell; \`unset $*\` when done"
        else
          command secret "$@"
        fi
      }
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          cmd: vars:
          "alias ${cmd}=${lib.escapeShellArg "secret run ${lib.concatStringsSep " " vars} -- ${cmd}"}"
        ) commands
      )}
    '';
  };
}
