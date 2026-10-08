{ pkgs }:
{
  dotfiles = pkgs.callPackage ./dotfiles-cli/package.nix { };
  sketchybar-toggle = pkgs.callPackage ./sketchybar-toggle/package.nix { };
  tsui = pkgs.callPackage ./tsui/package.nix { };
  whisper-models = pkgs.callPackage ./whisper-models/package.nix { };
}
