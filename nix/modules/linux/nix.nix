# Shared Nix settings for Linux (Home Manager standalone).
# Mirrors the flakes/experimental-features config from darwin/nix.nix.
{ dotfilesLib, ... }:
{
  flake.modules.homeManager.linuxNix =
    { pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      nix.package = pkgs.nix;
      nix.settings = dotfilesLib.nixSettings;
    };
}
