{
  config,
  lib,
  pkgs,
  self,
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
      default = "${userHome}/dotfiles";
      description = "Live checkout that GNU Stow deploys into the configured user's home directory.";
    };

    verbosity = lib.mkOption {
      type = lib.types.ints.between 0 5;
      default = 1;
      description = "GNU Stow verbosity passed to the activation script.";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.dotfilesStow = {
      text = ''
        sudo -H -u ${lib.escapeShellArg user} env \
          HOME=${lib.escapeShellArg userHome} \
          DOTFILES_REPO_ROOT=${lib.escapeShellArg cfg.repoRoot} \
          VERBOSITY=${toString cfg.verbosity} \
          ${self.packages.${pkgs.system}.dotfiles}/bin/dotfiles activate
      '';
    };
  };
}
