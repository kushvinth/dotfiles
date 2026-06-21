{
  config,
  lib,
  ...
}:
{
  options.dotfiles = {
    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/dotfiles";
      description = ''
        Live dotfiles checkout on disk (e.g. ~/dotfiles).
        Override in the host module if the repo lives elsewhere.
      '';
    };
  };
}
