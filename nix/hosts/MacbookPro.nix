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

  dotfiles.brewBundle = true;
  dotfiles.useOutOfStoreSymlinks = true;

  nix.enable = false;

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "MacbookPro";
    autoMigrate = true;
  };
}
