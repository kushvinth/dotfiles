{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./dotfiles.nix
  ];

  home.username = "MacbookPro";
  home.stateVersion = "24.11";
  home.homeDirectory = "/Users/MacbookPro";
}
