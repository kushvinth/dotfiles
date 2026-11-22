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
          fetchFromGitHub,
          swift,
        }:
        stdenv.mkDerivation (finalAttrs: {
          pname = "sketchybar-toggle";
          version = "0.4.0-pk-fix-untrigger";

          # Head of klockeph's pk/fix-untrigger branch, pinned to a commit so the hash
          # stays valid when the branch moves. Bump: git ls-remote <repo> pk/fix-untrigger
          src = fetchFromGitHub {
            owner = "klockeph";
            repo = "sketchybar-toggle";
            rev = "97b7cc00f6ece1bc638484d0d533b082c6c7e9da";
            hash = "sha256-zvntWlx05Lmls0YTEFjGiNpH3y2rbyXiRH/5+mLIp9c=";
          };

          nativeBuildInputs = [
            swift
          ];

          buildPhase = ''
            runHook preBuild
            swiftc -emit-module -module-name SketchyBarToggleCore -emit-library \
              Sources/SketchyBarToggleCore/*.swift \
              -Xlinker -install_name -Xlinker @rpath/libSketchyBarToggleCore.dylib
            swiftc -O -I . -L . -lSketchyBarToggleCore Sources/SketchyBarToggle/main.swift \
              -Xlinker -rpath -Xlinker @executable_path/../lib \
              -o sketchybar-toggle
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 sketchybar-toggle "$out/bin/sketchybar-toggle"
            install -Dm755 libSketchyBarToggleCore.dylib "$out/lib/libSketchyBarToggleCore.dylib"
            install -Dm644 SketchyBarToggleCore.swiftmodule "$out/lib/SketchyBarToggleCore.swiftmodule"
            runHook postInstall
          '';

          doCheck = false;

          meta = {
            description = "Lightweight macOS daemon that coordinates SketchyBar and the native menu bar";
            longDescription = ''
              sketchybar-toggle watches the mouse position and hides SketchyBar
              whenever the cursor enters the top trigger zone of the screen,
              letting the native macOS auto-hiding menu bar appear without
              overlapping SketchyBar, then slides SketchyBar back into view once
              the cursor moves away. Requires no Input Monitoring or Accessibility
              permissions.

              This build tracks klockeph's pk/fix-untrigger branch, which splits
              the single trigger-zone handler into separate trigger and
              untrigger zones so a click that dismisses the native menu bar
              restores SketchyBar correctly.
            '';
            homepage = "https://github.com/klockeph/sketchybar-toggle";
            changelog = "https://github.com/klockeph/sketchybar-toggle/commits/pk/fix-untrigger";
            license = lib.licenses.mit;
            platforms = lib.platforms.darwin;
            maintainers = [ ];
            mainProgram = "sketchybar-toggle";
          };
        })
      ) { };
    in
    {
      packages = lib.optionalAttrs isDarwin { sketchybar-toggle = pkg; };
      overlayAttrs = lib.optionalAttrs isDarwin { sketchybar-toggle = pkg; };
    };
}
