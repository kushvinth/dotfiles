{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      pkg = pkgs.callPackage (
        {
          lib,
          stdenv,
          swift,
          writeShellApplication,
        }:
        let
          # rolock: read-only mode (input frozen, screen stays live). The logic lives in
          # Hammerspoon (dot-config/hammerspoon/readonly.lua); this only talks to it over hs.ipc.
          cli = writeShellApplication {
            name = "rolock";
            text = ''
              hs=/opt/homebrew/bin/hs # Homebrew cask, not in nixpkgs

              # Hammerspoon can lose its hs.ipc message port while still running (seen
              # after days of uptime): hs then exits 69 and the hotkey silently does nothing.
              # Restart it and retry once; a restart also drops a live lock, so status never does.
              run() {
                local rc=0
                "$hs" -c "$1" || rc=$?
                [ "$rc" = 69 ] && [ "''${2:-}" = restart ] || return "$rc"
                echo "rolock: Hammerspoon's IPC port is gone, restarting it" >&2
                /usr/bin/killall Hammerspoon 2>/dev/null || true
                sleep 1
                /usr/bin/open -a Hammerspoon
                for _ in $(seq 20); do
                  "$hs" -c 'print(readonly ~= nil)' >/dev/null 2>&1 && break
                  sleep 0.5
                done
                "$hs" -c "$1"
              }

              case "''${1:-}" in
              lock) run 'readonly.lock()' restart ;;
              status) run 'print(readonly.locked and "locked" or "unlocked")' ;;
              # No Touch ID: SSH while locked, or the Hyper+S+0 backdoor (Karabiner).
              force-unlock) run 'readonly.unlock()' restart ;;
              *)
                echo "usage: rolock lock|status|force-unlock" >&2
                echo "unlock: Hyper+S+L while locked, then Touch ID" >&2
                exit 2
                ;;
              esac
            '';
          };
        in
        stdenv.mkDerivation {
          pname = "rolock";
          version = "0.1.0";
          src = ./_src;

          nativeBuildInputs = [ swift ];

          buildPhase = ''
            runHook preBuild
            swiftc -O verify.swift -o rolock-verify
            swiftc -O hud.swift -o rolock-hud
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 rolock-verify "$out/bin/rolock-verify"
            install -Dm755 rolock-hud "$out/bin/rolock-hud"
            ln -s ${cli}/bin/rolock "$out/bin/rolock"
            runHook postInstall
          '';

          meta = {
            description = "Read-only mode: freeze input, keep the screen live (Hammerspoon)";
            platforms = lib.platforms.darwin;
          };
        }
      ) { };
    in
    {
      packages = lib.optionalAttrs isDarwin { rolock = pkg; };
      overlayAttrs = lib.optionalAttrs isDarwin { rolock = pkg; };
    };
}
