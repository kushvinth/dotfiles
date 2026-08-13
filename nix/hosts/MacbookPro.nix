{
  config,
  ...
}:
{
  system.primaryUser = "MacbookPro";

  users.users.MacbookPro = {
    name = "MacbookPro";
    home = "/Users/MacbookPro";
  };

  dotfiles.brewBundle = false;

  nix.enable = true ;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    user = "MacbookPro";
    autoMigrate = true;
  };
}
