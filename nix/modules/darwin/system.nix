{
  lib,
  pkgs,
  user,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  # System-wide packages: only what the machine itself needs. Everyday CLI
  # tools go in nix/modules/home/default.nix (home.packages). Add here when:
  #  - it's a GUI app: nix-darwin copies these into /Applications/Nix Apps
  #    (the Dock in defaults.nix points there);
  #  - a script calls it through /run/current-system/sw (sketchybar plugins,
  #    FZF_BASE in .zshenv);
  #  - it manages this machine (nh).
  environment.systemPackages = with pkgs; [
    # Base shell tools, also there for root and sudo
    bash
    coreutils
    zsh

    # Called by sketchybar plugins via /run/current-system/sw/bin
    blueutil
    curl
    gh
    git
    jq
    python3

    # FZF_BASE points at /run/current-system/sw/share/fzf
    fzf

    # Managing this machine
    nh
    nix-zsh-completions # _nix, _nix-build, ... (this profile's site-functions is on fpath in .zshrc)

    # GUI apps
    gitkraken
    neovide
    obsidian
    postman
    prismlauncher
    qbittorrent
    wireshark
    zed-editor
    # zotero: nixpkgs build fails on darwin (10.0.4); installed via the `zotero` cask instead
    #ghostty        # available in nixpkgs unstable

    # Tailscale: the Mac App Store app (installed via mas, see homebrew.nix) ships its own CLI,
    # aliased as `tailscale` in .zshalias. Don't add the nixpkgs CLI: its
    # version drifts from the app's daemon.
  ];

  # set-environment (sourced from /etc/zshenv) rebuilds PATH from scratch, so
  # Homebrew must be declared here or launchd agents (skhd → yabai) lose it.
  # Order: nix profiles first, then these, then /usr/bin etc.
  environment.systemPath = lib.mkOrder 1100 [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  programs.zsh.enable = true;
  # Lands in nix-darwin's /etc/zshenv, right after set-environment (nix PATH,
  # NIX_PROFILES, per-user profile). The user's ~/.config/zsh does the rest.
  programs.zsh.shellInit = ''
    export ZDOTDIR="$HOME/.config/zsh"
  '';
  # oh-my-zsh owns compinit; /etc/zshrc is skipped anyway (NOSYSZSHRC in .zshenv).
  programs.zsh.enableCompletion = false;

  # Per-project env via .envrc; `use flake` caches dev shells (nix-direnv).
  # The zsh hook lives in .zshrc because /etc/zshrc is skipped.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Prebuilt nix-index DB (flake input nix-index-database): `nix-locate`,
  # command-not-found suggestions (sourced from .zshrc), and `, <cmd>` to run
  # any nixpkgs program without installing it.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  # `nh darwin switch` (alias darnix) builds as you, shows a package diff, then
  # sudo-activates. NH_FLAKE lets it run from any directory.
  environment.variables.NH_FLAKE = "/Users/${user}/dotfiles/nix";

  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";

}
