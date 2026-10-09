{
  pkgs,
  user,
  ...
}:
{
  imports = [
    ./dotfiles.nix
  ];

  home.username = user;
  home.stateVersion = "24.11";
  home.homeDirectory = "/Users/${user}";

  home.packages = [
    pkgs.tsui
  ];
}
