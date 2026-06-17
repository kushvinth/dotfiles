# =============================================================================
# Declarative app management for nix-darwin
# Sorted by source priority: nixpkgs → homebrew brews → homebrew casks → mas
# =============================================================================

{ pkgs, ... }:

{
  # ===========================================================================
  # 1. NIXPKGS — CLI tools & packages available in nixpkgs for darwin
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # From your brew list — all available in nixpkgs
    bash
    bat
    certifi
    coreutils
    deno
    eza
    gh            # GitHub CLI
    git-lfs
    gnupg
    gnutls
    mas           # Mac App Store CLI
    ncdu
    neovim
    node
    openssl
    perl
    pipx
    podman
    readline
    simdjson
    sketchybar   # also a service below
    skhd          # also a service below
    sqlite
    tree
    uv
    yt-dlp

    # GUI apps available in nixpkgs on darwin
    obsidian
    discord
    spotify
    vlc
    zotero
    gitkraken
    wireshark
    qbittorrent
    postman
    jellyfin-media-player
    ghostty        # available in nixpkgs unstable
    zed-editor
    vscode
    # Note: ghostty build may be broken on some nixpkgs revisions; fall back to cask if needed
  ];

  # nix-darwin services — managed via nixpkgs
  services.sketchybar.enable = true;
  services.skhd.enable = true;
  services.yabai.enable = true;
  # services.karabiner-elements.enable = true;
  # ^ nix-darwin has a module for this but macOS permission prompts
  #   make declarative management fragile; recommend cask instead.

  # ===========================================================================
  # 2. HOMEBREW — managed declaratively via nix-darwin's homebrew module
  # ===========================================================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";     # remove anything not listed here
      upgrade = true;
    };

    # -------------------------------------------------------------------------
    # 2a. Brews (CLI formulae not in nixpkgs or preferred from brew)
    # -------------------------------------------------------------------------
    brews = [
      "immich-go"    # not in nixpkgs
      "mactop"       # macOS-specific top; not in nixpkgs
      "merve"        # not in nixpkgs
      "mlx"          # Apple MLX; not in nixpkgs
      "nbytes"       # not in nixpkgs
      "sketchybar"   # can also be run as brew formula (tap required)
      "temporal"     # Temporal CLI; not in nixpkgs
    ];

    # -------------------------------------------------------------------------
    # 2b. Casks (GUI apps not available / impractical in nixpkgs on darwin)
    # -------------------------------------------------------------------------
    casks = [
      # Window management / system tools
      "nikitabobko/tap/aerospace"  # requires custom tap
      "alt-tab"
      "alfred"
      "raycast"
      "rectangle"
      "karabiner-elements"
      "linear-linear"
      "linearmouse"
      "lunar"          # display brightness control
      "macs-fan-control"
      "lulu"           # Little Snitch alternative
      "cheatsheet"
      "keycastr"
      "homerow"
      "swiftbar"

      # Terminals
      # ghostty — prefer nixpkgs; uncomment if nixpkgs build is broken:
      # "ghostty"

      # Browsers
      "arc"
      "google-chrome"
      "zen-browser"

      # Dev tools
      "cursor"
      "github"         # GitHub Desktop
      "orbstack"       # Docker replacement
      "docker"         # keep if you still want Docker Desktop
      "warp"
      "lm-studio"
      "ollama"
      "astro"          # if this refers to Astro app; remove if different

      # Communication
      "telegram"       # telegram-desktop not on darwin nixpkgs
      "texts"
      "zoom"
      "loom"

      # Media / creative
      "spotify"        # can also use nixpkgs; cask is simpler for auto-updates
      "vlc"            # can also use nixpkgs
      "mochi-diffusion"
      "discord"        # can also use nixpkgs
      "voicemod"

      # Utilities
      "cleanshot"
      "cleanmymac"
      "anydesk"
      "vnc-viewer"
      "balenaetcher"
      "raspberry-pi-imager"
      "wakatime"       # IDE time tracker daemon
      "lookaway"
      "cold-turkey-blocker"
      "iterm2"         # if you still want iTerm alongside Ghostty

      # Network / security
      "tailscale"
      "shadowsocksx-ng"
      "wireshark"      # can also use nixpkgs; cask installs .app bundle
      "zenmap"
      "wireguard-tools"  # GUI handled by mas; formula for CLI

      # Knowledge / notes
      "notion"
      "obsidian"       # can also use nixpkgs
      "logseq"         # can also use nixpkgs
      "zotero"         # can also use nixpkgs

      # Games / entertainment
      "steam"
      "minecraft"
      "sklauncher"

      # Creative / design
      "sketch"
      "sf-symbols"
      "kicad"
      "godot"          # can also use nixpkgs; cask gives proper .app

      # Media servers
      "jellyfin"
      "jellyfin-media-player"

      # Misc
      "qbittorrent"    # can also use nixpkgs
      "postman"        # can also use nixpkgs
      "mysqlworkbench"
      "gitkraken"      # can also use nixpkgs; cask stays more up-to-date
      "chatgpt"
    ];

    # -------------------------------------------------------------------------
    # 2c. Taps needed for the above casks/brews
    # -------------------------------------------------------------------------
    taps = [
      "nikitabobko/tap"    # AeroSpace
      "FelixKratz/formulae" # sketchybar (if using brew version)
    ];

    # -------------------------------------------------------------------------
    # 2d. Mac App Store apps — managed via homebrew mas
    # -------------------------------------------------------------------------
    masApps = {
      "Battery Health 2"    = 1120214373;
      "CleanMyDrive 2"      = 523620159;
      "CleanMyKeyboard"     = 6468120888;
      "Delete Apps"         = 1033808943;
      "GarageBand"          = 682658836;
      "iMovie"              = 408981434;
      "Keynote"             = 361285480;
      "Microsoft Excel"     = 462058435;
      "Microsoft PowerPoint"= 462062816;
      "Microsoft Word"      = 462054704;
      "Numbers"             = 361304891;
      "Pages"               = 361309726;
      "RunCat"              = 1429033973;
      "Samorost 1"          = 1561324007;
      "Slack"               = 803453959;
      "The Unarchiver"      = 425424353;
      "WhatsApp"            = 310633997;
      "WireGuard"           = 1451685025;
    };
  };

  # ===========================================================================
  # 3. MANUAL INSTALL — cannot be managed by any package manager
  #    Install these by hand and document them here for reproducibility.
  # ===========================================================================

  # The following apps have no brew cask, no nixpkgs package, and no MAS entry.
  # Install manually from their respective websites/sources:
  #
  #  App                   | Source / URL
  #  ----------------------|------------------------------------------------
  #  Autodesk Fusion 360   | https://www.autodesk.com/products/fusion-360
  #  CrossOver             | https://www.codeweavers.com/crossover
  #  MaciOSRecorder        | https://www.apowersoft.com/iphone-screen-recorder (or brew cask apowersoft-iphone-recorder — check)
  #  MacApowerMirror       | https://www.apowersoft.com/phone-mirror
  #  Barik / BarikEnhanced | Personal/custom build — no public release
  #  Karik                 | Personal/custom build — no public release
  #  SwipeAeroSpace        | https://github.com/— check repo
  #  Antigravity / IDE     | No public package
  #  Wineskin              | https://github.com/Gcenx/WineskinServer (no cask)
  #  FreeFlow              | Check App Store or vendor
  #  Amplitude Soundboard  | https://apps.apple.com/app — check MAS ID
  #  Excon 2023            | Institution-specific — no public package
  #  Apple Music RPC       | https://github.com/— Discord RPC sidecar; manual
  #  Pixelsnap (PixelPanel) | https://getpixelsnap.com (check cask pixelsnap)
  #  Numbers Creator Studio| MAS variant — check if same as Numbers above
  #  Pages Creator Studio  | MAS variant — check if same as Pages above
  #  Keynote Creator Studio| MAS variant — check if same as Keynote above
  #  InstallForMacOSApple  | macOS installer helper — system tool
  #  Slime Rancher         | Steam only — manage via Steam
  #  Machinarium Coll. Ed. | Steam/GOG — manage via Steam
  #  SuperTuxKart          | https://supertuxkart.net (check brew cask supertuxkart)
  #  TuxPaint              | https://tuxpaint.org (check brew cask tuxpaint)
  #  exo                   | https://github.com/exo-explore/exo — pip install or manual
  #  WallSpace             | No known cask; check https://wallspace.app
  #  AstroNvim / Astro IDE | If this is astronvim — it's a neovim config, not an app
  #  Samorost 1            | ✓ Already in masApps above
  #  Safe Exam Browser     | https://safeexambrowser.org/download_en.html (check cask)
}
