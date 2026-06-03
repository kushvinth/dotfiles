{
  config,
  pkgs,
  paths,
  lib,
  ...
}:
let
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home;
  brewBundle = config.dotfiles.brewBundle;
in
{
  options.dotfiles = {
    brewBundle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run brew bundle install from repo Brewfile after switch.";
    };
  };

  config = {
    system.activationScripts.dotfilesSubmodules.text = ''
      echo "dotfiles: updating git submodules..." >&2
      ${pkgs.git}/bin/git -C ${paths.repoRoot} submodule update --init --recursive
    '';

    system.activationScripts.dotfilesZshPlugins = {
      deps = [
        "dotfilesSubmodules"
      ];
      text = ''
        repoPlugins=${paths.repoRoot}/dot-config/zsh/assets/custom/plugins
        targetPlugins=${userHome}/.config/zsh/assets/custom/plugins
        if [[ -d "$repoPlugins" && ! -d "$targetPlugins/forgit" ]]; then
          echo "dotfiles: linking zsh OMZ plugins from repo..." >&2
          mkdir -p "$(dirname "$targetPlugins")"
          ln -sfn "$repoPlugins" "$targetPlugins"
        fi
      '';
    };

    system.activationScripts.dotfilesBrewBundle = lib.mkIf brewBundle {
      deps = [
        "dotfilesSubmodules"
        "dotfilesZshPlugins"
      ];
      text = ''
        if [ -f ${paths.brewfile} ] && command -v brew >/dev/null 2>&1; then
          echo "dotfiles: brew bundle install..." >&2
          sudo -u ${user} brew bundle install --file ${paths.brewfile}
        fi
      '';
    };
  };
}
