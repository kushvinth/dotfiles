{
  lib,
  stdenv,
  fetchFromGitHub,
  swift,
  swiftpm,
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
    swiftpm
  ];

  env.SWIFTPM_CACHE_DIR = "swiftpm-cache";

  buildPhase = ''
    runHook preBuild
    swift build \
      -c release \
      --cache-path "$SWIFTPM_CACHE_DIR" \
      --disable-sandbox
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 .build/release/sketchybar-toggle "$out/bin/sketchybar-toggle"
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
