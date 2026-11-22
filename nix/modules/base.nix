{ config, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
in
{
  flake.modules.generic.homeManagerIntegration =
    { user, ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-bak";
        extraSpecialArgs = {
          inherit user;
        };
        sharedModules = [
          homeManager.base
          homeManager.secrets
        ];
        users.${user} = {
          home = {
            username = user;
            homeDirectory = "/Users/${user}";
            stateVersion = "24.11";
          };
        };
      };
    };

  flake.modules.darwin.base = {
    imports = [
      config.flake.modules.generic.homeManagerIntegration
      darwin.apps
      darwin.backup
      darwin.defaults
      darwin.fonts
      darwin.homebrew
      darwin.nix
      darwin.security
      darwin.services
      darwin.tailscale
    ];
  };

  flake.modules.homeManager.linux = {
    imports = [
      homeManager.base
      homeManager.linuxNix
      homeManager.linuxZshenv
      homeManager.linuxDoctor
    ];
  };

  flake.modules.homeManager.base = {
    imports = [
      homeManager.completions
      homeManager.doctor
      homeManager.dotfiles
      homeManager.git
      homeManager.packages
      homeManager.setup
      homeManager.zsh
    ];
  };
}
