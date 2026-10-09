{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.stow;
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home;
in
{
  options.dotfiles.stow = {
    enable = lib.mkEnableOption "deployment of this checkout with GNU Stow";

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = config.home-manager.users.${user}.dotfiles.repoRoot;
      description = "Live checkout that GNU Stow deploys into the configured user's home directory.";
    };

    verbosity = lib.mkOption {
      type = lib.types.ints.between 0 5;
      default = 1;
      description = "GNU Stow verbosity passed to the activation script.";
    };
  };

  config = lib.mkIf cfg.enable {
    # nix-darwin only runs a fixed set of activation script names (preActivation,
    # postActivation, ...); any other name is evaluated but never executed.
    # A stow conflict should not fail the whole switch, so it only warns.
    system.activationScripts.postActivation.text = ''
      sudo -H -u ${lib.escapeShellArg user} env \
        HOME=${lib.escapeShellArg userHome} \
        DOTFILES_REPO_ROOT=${lib.escapeShellArg cfg.repoRoot} \
        VERBOSITY=${toString cfg.verbosity} \
        ${pkgs.dotfiles}/bin/dotfiles activate \
        || echo "dotfiles: stow failed (see above); fix the conflict and run 'make stow'" >&2
    '';
  };
}
