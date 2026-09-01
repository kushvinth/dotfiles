{ config, ... }:
{
  homebrew = {
    enable = true;
    onActivation.cleanup = "check";
    onActivation.autoUpdate = false;
    brews = [
      "immich-go"
      "apfel"
      "herdr"
      "dops"
      "mole"
      "sketchybar"
      "skhd"
      "yabai"

    ];
    casks = [
      # Window management / system tools
      "alt-tab"
      "homerow"
      "karabiner-elements"
      "keycastr"
      "ghostty"
      "linearmouse"
      "lulu"
      "lunar"
      "macs-fan-control"
      "raycast"
      "rectangle"

      # Browsers
      "google-chrome"
      "arc"
      "brave-browser"

      # Dev tools
      "cursor"
      "codex"
      "lm-studio"
      "ollama-app"
      "orbstack"
      "dbeaver-community"
      "iterm2"
      "hammerspoon"

      # Communication
      "zoom"
      "slack"

      # Media / creative
      "discord"

      # Utilities
      "cleanshot"
      "cold-turkey-blocker"
      "wakatime"

      # Network / security
      "tailscale-app"

      # Creative / design
      "sf-symbols"

    ];

    taps = [
      "FelixKratz/formulae"
      "koekeishiya/formulae"
      "malpern/tap"
      "mikescher/tap"
    ];

    masApps = {
      "Battery Health 2" = 1120214373;
      "CleanMyKeyboard" = 6468120888;
      "Delete Apps" = 1033808943;
      "iMovie" = 408981434;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "RunCat" = 1429033973;
      "Slack" = 803453959;
      "The Unarchiver" = 425424353;
      "WhatsApp" = 310633997;
    };
  };
}
