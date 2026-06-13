{
  ...
}:
{
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = false;
    brews = [
      "mas"
      "immich-go"
      "sketchybar"
    ];
    casks = [
      # Window management / system tools
      "alt-tab"
      "raycast"
      "rectangle"
      "karabiner-elements"
      "linearmouse"
      "lunar"          
      "macs-fan-control"
      "lulu"           
      #"cheatsheet"
      "keycastr"
      "homerow"

      # Terminals
      # ghostty — prefer nixpkgs; uncomment if nixpkgs build is broken:
      # "ghostty"
      #"iterm2"         # if you still want iTerm alongside Ghostty

      # Browsers
      "google-chrome"
      "zen-browser"

      # Dev tools
      "cursor"
      "orbstack"       # Docker replacement
      #"docker"         # keep if you still want Docker Desktop
      "lm-studio"
      "ollama"

      # Communication
      "zoom"

      # Media / creative
      #"vlc"            # can also use nixpkgs
      "discord"        # can also use nixpkgs

      # Utilities
      "cleanshot"
      "cleanmymac"
      #"anydesk"
      #"vnc-viewer"
      #"balenaetcher"
      "wakatime"       # IDE time tracker daemon
      "cold-turkey-blocker"

      # Network / security
      "tailscale"    

      # Games / entertainment
      #"sklauncher"

      # Creative / design
      "sf-symbols"
      #"kicad"

#      # Media servers
#      #"jellyfin-media-player"

    ];
    
    taps = [
      "nikitabobko/tap"    # AeroSpace
      "FelixKratz/formulae" # sketchybar (if using brew version)
    ];

    masApps = {
      "Battery Health 2"    = 1120214373;
      "CleanMyDrive 2"      = 523620159;
      "CleanMyKeyboard"     = 6468120888;
      "Delete Apps"         = 1033808943;
      "iMovie"              = 408981434;
      "Microsoft Excel"     = 462058435;
      "Microsoft PowerPoint"= 462062816;
      "Microsoft Word"      = 462054704;
      "RunCat"              = 1429033973;
      "Slack"               = 803453959;
      "The Unarchiver"      = 425424353;
      "WhatsApp"            = 310633997;
    };
  };
}



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

