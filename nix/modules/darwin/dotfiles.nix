# Host-level toggles for dotfiles; forwards Home Manager options from nix/hosts/*.nix.
{
  config,
  lib,
  ...
}:
let
  user = config.system.primaryUser;
in
{
  options.dotfiles.useOutOfStoreSymlinks = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Symlink configs from the live repo checkout (recommended on macOS).";
  };

  config.home-manager.users.${user}.dotfiles.useOutOfStoreSymlinks =
    config.dotfiles.useOutOfStoreSymlinks;
}
