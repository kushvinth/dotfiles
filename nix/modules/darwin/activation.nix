{
  config,
  ...
}:
let
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home;
  liveRepoRoot = config.home-manager.users.${user}.dotfiles.repoRoot;
in
{
  config = {
    system.activationScripts.dotfilesZshPlugins = {
      text = ''
        repoPlugins=${liveRepoRoot}/dot-config/zsh/assets/custom/plugins
        targetPlugins=${userHome}/.config/zsh/assets/custom/plugins
        if [[ -d "$repoPlugins" && ! -d "$targetPlugins/forgit" ]]; then
          echo "dotfiles: linking zsh OMZ plugins from repo..." >&2
          sudo -H -u ${user} env HOME=${userHome} mkdir -p "$(dirname "$targetPlugins")"
          sudo -H -u ${user} env HOME=${userHome} ln -sfn "$repoPlugins" "$targetPlugins"
        fi
      '';
    };

  };
}
