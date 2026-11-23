{ dotfilesLib, ... }:
{
  flake.modules.darwin.fonts =
    { pkgs, ... }:
    {
      fonts.packages = dotfilesLib.fonts pkgs;
    };
}
