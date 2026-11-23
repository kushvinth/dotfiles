{ dotfilesLib, ... }:
{
  flake.modules.darwin.nix =
    { pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;

      nix.settings = dotfilesLib.nixSettings;

      # Base tools available to root and system scripts (e.g. sketchybar)
      environment.systemPackages = with pkgs; [
        bash
        coreutils
        zsh
        blueutil
        curl
        gh
        git
        jq
        python3
        rolock
        fzf
        nh
        nix-zsh-completions
      ];

      programs.zsh.enable = true;
      programs.zsh.shellInit = ''
        export ZDOTDIR="$HOME/.config/zsh"
      '';
      programs.zsh.enableCompletion = false;

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        direnvrcExtra = ''
          use_secret() {
            eval "$(secret env "$@")"
          }
        '';
      };

      programs.nix-index.enable = true;
      programs.nix-index-database.comma.enable = true;

      nix.gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        };
        options = "--delete-older-than 14d";
      };
      nix.optimise = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 4;
          Minute = 0;
        };
      };
    };
}
