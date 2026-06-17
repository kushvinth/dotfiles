{ config, ... }:
{
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = false;
    brews = [
      "mas"
      "immich-go"
      "sketchybar"
      "yabai"
      "skhd"
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
      "zen"

      # Dev tools
      "cursor"
      "orbstack"       
      #"docker"       
      "lm-studio"
      "ollama-app"

      # Communication
      "zoom"

      # Media / creative
      #"vlc"            # can also use nixpkgs
      "discord"        # can also use nixpkgs

      # Utilities
      "cleanshot"
      #"balenaetcher"
      "wakatime" 
      "cold-turkey-blocker"

      # Network / security
      "tailscale-app"    

      # Games / entertainment
      #"sklauncher"

      # Creative / design
      "sf-symbols"
    ];
    
    taps = [
      "koekeishiya/formulae"
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
