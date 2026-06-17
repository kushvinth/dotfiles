{
  config,
  pkgs,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  # CLI on /run/current-system/sw/bin — avoid duplicating Brewfile formulae.
  environment.systemPackages = with pkgs; [
    # From your brew list — all available in nixpkgs
    bash
    bat
    coreutils
    deno
    eza
    fzf
    gh 
    fd           
    git-lfs
    gnupg
    gnutls
    lazygit
    mas           
    mkalias
    ncdu
    neovim
    nodejs
    openssl
    perl
    podman
    readline
    stow
    simdjson
    starship
    sketchybar   # also a service below
    skhd          # also a service below
    sqlite
    tree
    uv
    vscode
    yt-dlp
    zoxide

    # GUI apps available in nixpkgs on darwin
    obsidian
    discord

    zotero
    gitkraken
    wireshark
    qbittorrent
    postman
    #ghostty        # available in nixpkgs unstable
    zed-editor
    vscode
  ];

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  programs.zsh.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.activationScripts.applications.text = let
    env = pkgs.buildEnv {
      name = "system-applications";
      paths = config.environment.systemPackages;
      pathsToLink = [ "/Applications" ];
    };
  in
    pkgs.lib.mkForce ''
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';
}
