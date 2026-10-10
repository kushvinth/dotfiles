{ config, lib, ... }:
{
  homebrew = {
    enable = true;
    # "check": abort activation if anything installed is not declared below
    # (never silently uninstalls or deletes app data like "zap" does).
    onActivation.cleanup = "check";
    # Taps are pinned flake inputs (hosts/MacbookPro.nix), so `brew update` has
    # nothing to fetch: `darnix --update` bumps flake.lock, then each
    # `darwin-rebuild switch` upgrades to exactly those versions.
    onActivation.autoUpdate = false;
    onActivation.upgrade = true;
    # Also upgrade casks that self-update (Chrome, Cursor, Slack, ...).
    greedyCasks = true;
    brews = [
      "immich-go"
      "apfel"
      "herdr"
      "dops"
      "mole"
      # Fully qualified so nix-darwin emits `trusted: true` (Homebrew 6+ tap trust).
      "FelixKratz/formulae/sketchybar"
      "asmvik/formulae/skhd"
      "asmvik/formulae/yabai"
      "gromgit/fuse/ext4fuse-mac"
      "git-filter-repo"
      "mas" # App Store CLI for the shell; the switch uses nixpkgs' mas (nix/modules/home/setup.nix)
      "gnhf" # npm-only agent runner, not in nixpkgs
    ];
    casks = [
      # Window management / system tools
      "alt-tab"
      "homerow"
      "karabiner-elements"
      "finetune"
      "keycastr"
      "ghostty"
      "linearmouse"
      "lulu"
      "lunar"
      "macs-fan-control"
      "raycast"
      "rectangle"
      "alfred"
      # "cheatsheet" # cask download 404s upstream
      "swiftbar"
      "nikitabobko/tap/aerospace"
      "mediosz/tap/swipeaerospace"

      # Browsers
      "google-chrome"
      "arc"
      "zen"
      "brave-browser"
      "safe-exam-browser"

      # Dev tools
      "cursor"
      "codex"
      "lm-studio"
      "ollama-app"
      "orbstack"
      "dbeaver-community"
      "iterm2"
      "hammerspoon"
      "visual-studio-code"
      "antigravity"
      "antigravity-ide"
      "claude"
      "chatgpt"
      "itermai"
      "mysqlworkbench"
      "godot"
      "exo"
      "mochi-diffusion"
      "qmk-toolbox"
      "raspberry-pi-imager"
      "balenaetcher"
      "icon-composer"

      # Communication
      "zoom"
      "slack"
      "telegram-a"
      "anydesk"
      "kde-connect"

      # Media / creative
      "discord"
      "vlc"
      "voicemod"
      "soulseek"
      "supertuxkart"

      # Utilities
      # "cleanshot"
      "cold-turkey-blocker"
      "wakatime"
      "notion"
      "zotero"

      # Network / security
      # "tailscale-app" # replaced by the Mac App Store app (installed via mas)
      # "angry-ip-scanner" # cask disabled upstream (fails Gatekeeper)
      # "zenmap" # cask disabled upstream (fails Gatekeeper)

      # Creative / design
      "sf-symbols"
      "figma"
      "bambu-studio"
      "wallspace"

    ];

    # Declared (and pinned) in nix-homebrew.taps; keep the Brewfile in sync.
    # Third-party taps are marked trusted (Homebrew 6+ tap trust).
    taps = map (name: {
      inherit name;
      trusted = !lib.hasPrefix "homebrew/" name;
    }) (builtins.attrNames config.nix-homebrew.taps);

    # App Store apps are installed by nix/modules/home/setup.nix:
    # brew bundle can't find mas under `sudo darwin-rebuild`, so any masApps
    # entry aborts activation with "mas installation failed".
    masApps = { };
  };
}
