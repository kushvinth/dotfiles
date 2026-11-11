{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      isAarch64Darwin = pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isAarch64;
      pkg = pkgs.callPackage (
        {
          stdenvNoCC,
          fetchurl,
          unzip,
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "hex";
          version = "3.3.0";

          src = fetchurl {
            url = "https://github.com/anomalyco/hex/releases/download/v${finalAttrs.version}/hex-${finalAttrs.version}-macos-arm64.zip";
            hash = "sha256-HCjWoeeQMj7xmbSBvJIx5q2OcKF4W+hJE+Cnvwpuuzk=";
          };

          nativeBuildInputs = [ unzip ];

          sourceRoot = ".";

          dontPatch = true;
          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/Applications
            cp -R Hex.app $out/Applications/
            mkdir -p $out/bin
            ln -s $out/Applications/Hex.app/Contents/MacOS/hex $out/bin/hex
            runHook postInstall
          '';

          meta = {
            description = "Local-first voice dictation";
            homepage = "https://github.com/anomalyco/hex";
            platforms = [ "aarch64-darwin" ];
            mainProgram = "hex";
          };
        })
      ) { };
    in
    {
      packages = lib.optionalAttrs isAarch64Darwin { hex = pkg; };
      overlayAttrs = lib.optionalAttrs isAarch64Darwin { hex = pkg; };
    };
}
