# Extensible read-only health check runner.
# Platform modules contribute their checks via `options.dotfiles.doctor.checks`.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dotfiles.doctor;

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
      for cmd in git curl python3 tsui; do
        resolved="$(env -i HOME="$HOME" USER="$USER" TERM=dumb /bin/sh -c "command -v $cmd" 2>/dev/null || true)"
        case "$resolved" in
          /run/current-system/* | /etc/profiles/* | /nix/* | /opt/homebrew/* | */.nix-profile/*) ok "$cmd → $resolved" ;;
          "") bad "$cmd not found" ;;
          *) ok "$cmd → $resolved" ;;
        esac
      done

      # Platform-contributed checks (launchd, Keychain, etc.)
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_name: snippet: snippet) cfg.checks)}

      echo "Updates"
      age=$((($(date +%s) - ${toString inputs.nixpkgs.lastModified}) / 86400))
      if [ "$age" -le 30 ]; then ok "nixpkgs pinned $age days ago"; else warn "nixpkgs pinned $age days ago"; fi

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
  options.dotfiles.doctor = {
    checks = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      description = "Platform-specific health check snippets. Key is check name, value is shell code.";
    };
  };

  config = {
    home.packages = [ doctor ];

    home.activation.dotfilesDoctor = lib.hm.dag.entryAfter [
      "dotfilesBatCache"
      "dotfilesNvimPlugins"
    ] "${lib.getExe doctor}";
  };
}
