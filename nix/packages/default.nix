{ pkgs }:
{
  dotfiles = pkgs.callPackage ./dotfiles-cli/package.nix { };
  sketchybar-toggle = pkgs.callPackage ./sketchybar-toggle/package.nix { };
}
