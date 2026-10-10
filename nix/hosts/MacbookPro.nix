{
  inputs,
  user,
  ...
}:
{
  system.primaryUser = user;

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  nix.enable = true;
  services.sketchybar-toggle.enable = true;
  services.borgmatic-agent.enable = true;
  services.local-dictation.enable = true;

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    inherit user;
    autoMigrate = true;

    # Taps come from flake inputs (see flake.nix) instead of `brew tap` clones,
    # so Homebrew is pinned and versioned with flake.lock like everything else.
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
    };
    # Homebrew 6+ refuses third-party taps until they're trusted.
    trust.taps = [
      "felixkratz/formulae"
      "asmvik/formulae"
      "mikescher/tap"
      "gromgit/fuse"
      "nikitabobko/tap"
      "mediosz/tap"
    ];
  };
}
