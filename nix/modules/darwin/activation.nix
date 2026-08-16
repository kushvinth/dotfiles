{
  config,
  pkgs,
  ...
}:
let
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home;
  liveRepoRoot = config.home-manager.users.${user}.dotfiles.repoRoot;
in
{
  config = {
    system.activationScripts.dotfilesSubmodules.text = ''
      if [ "''${CI:-}" = "true" ]; then
        echo "dotfiles: skipping submodule update in CI" >&2
      else
        echo "dotfiles: updating git submodules..." >&2
        ${pkgs.git}/bin/git -C ${liveRepoRoot} submodule update --init --recursive
      fi
    '';

    system.activationScripts.dotfilesZshPlugins = {
      deps = [
        "dotfilesSubmodules"
      ];
      text = ''
        repoPlugins=${liveRepoRoot}/dot-config/zsh/assets/custom/plugins
        targetPlugins=${userHome}/.config/zsh/assets/custom/plugins
        if [[ -d "$repoPlugins" && ! -d "$targetPlugins/forgit" ]]; then
          echo "dotfiles: linking zsh OMZ plugins from repo..." >&2
          mkdir -p "$(dirname "$targetPlugins")"
          ln -sfn "$repoPlugins" "$targetPlugins"
        fi
      '';
    };

  };
}
