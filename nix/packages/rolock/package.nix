{
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

      case "''${1:-}" in
      lock) "$hs" -c 'readonly.lock()' ;;
      status) "$hs" -c 'print(readonly.locked and "locked" or "unlocked")' ;;
      # No Touch ID: SSH while locked, or the Hyper+S+0 backdoor (Karabiner).
      force-unlock) "$hs" -c 'readonly.unlock()' ;;
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
  src = ./.;

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

  meta.description = "Read-only mode: freeze input, keep the screen live (Hammerspoon)";
}
