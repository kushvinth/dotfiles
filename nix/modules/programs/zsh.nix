{
  flake.modules.homeManager.zsh =
    { user, ... }:
    {
      home.sessionVariables = {
        NH_FLAKE = "/Users/${user}/dotfiles/nix";
      };
    };
}
