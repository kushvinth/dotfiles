{ config, inputs, ... }:
let
  inherit (config.flake.modules) darwin;
in
{
  configurations.darwin.MacbookPro.module =
    { user, ... }:
    {
      imports = [ darwin.base ];

      system.stateVersion = 6;

      system.primaryUser = user;
      users.users.${user} = {
        name = user;
        home = "/Users/${user}";
      };

      nix-homebrew = {
        enable = true;
        enableRosetta = false;
        inherit user;
        autoMigrate = true;
        mutableTaps = false;
        taps = {
          "homebrew/homebrew-core" = inputs.homebrew-core;
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
          "felixkratz/homebrew-formulae" = inputs.tap-felixkratz;
          "asmvik/homebrew-formulae" = inputs.tap-asmvik;
          "mikescher/homebrew-tap" = inputs.tap-mikescher;
          "gromgit/homebrew-fuse" = inputs.tap-gromgit-fuse;
          "nikitabobko/homebrew-tap" = inputs.tap-nikitabobko;
          "mediosz/homebrew-tap" = inputs.tap-mediosz;
          "nextfire/homebrew-tap" = inputs.tap-nextfire;
        };
        trust.taps = [
          "felixkratz/formulae"
          "asmvik/formulae"
          "mikescher/tap"
          "gromgit/fuse"
          "nikitabobko/tap"
          "mediosz/tap"
          "nextfire/tap"
        ];
      };
    };
}
