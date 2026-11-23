{
  flake.modules.homeManager.secrets =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dotfiles.secrets;

      commands = lib.zipAttrs (
        lib.concatLists (lib.mapAttrsToList (var: s: map (c: { ${c} = var; }) s.commands) cfg)
      );

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
              echo "secret: $1 is not declared (dotfiles.secrets); known: ''${!services[*]}" >&2
              exit 1
            fi
            echo "''${services[$1]}"
          }
          present() { /usr/bin/security find-generic-password -a "$USER" -s "$1" >/dev/null 2>&1; }
          value() { /usr/bin/security find-generic-password -a "$USER" -s "$(service "$1")" -w; }
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
      options.programs.secret = {
        enable = lib.mkEnableOption "unified secret management CLI";
        package = lib.mkOption {
          type = lib.types.package;
          default = secret;
          description = "The secret CLI package implementation.";
        };
      };

      options.dotfiles.secrets = lib.mkOption {
        description = "Env vars whose values are managed securely.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              service = lib.mkOption {
                type = lib.types.str;
                description = "Secret identifier or service name holding the value.";
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
        programs.secret.enable = lib.mkDefault true;

        dotfiles.secrets = {
          BORG_PASSPHRASE = {
            service = "borg-xteink";
            commands = [ "borg" ];
          };
          GITHUB_PERSONAL_ACCESS_TOKEN = {
            service = "github-personal-access-token";
            commands = [ "opencode" ];
          };
          DEEPSEEK_API_KEY.service = "deepseek-api-key";
          CLAUDE_CODE_OAUTH_TOKEN.service = "claude-code-oauth-token";
          GOTIFY_URL.service = "gotify-url";
          GOTIFY_TOKEN.service = "gotify-token";

          EXPLABS_API_KEY.service = "explabs-api-key";
          OPENAI_API_KEY.service = "openai-api-key";
          ELEVENLABS_API_KEY.service = "elevenlabs-api-key";
          WAKAPI_API_KEY.service = "wakapi-api-key";
          HEROKU_API_KEY = {
            service = "heroku-api-key";
            commands = [ "heroku" ];
          };
          RCLONE_CONFIG_STORAGEBOX_PASS = {
            service = "rclone-storagebox";
            commands = [ "rclone" ];
          };
        };

        home.packages = lib.optional config.programs.secret.enable config.programs.secret.package;

        xdg.dataFile."dotfiles/secrets.zsh".text = ''
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
    };
}
