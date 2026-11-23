{
  flake.modules.darwin.homebrew =
    { config, lib, ... }:
    {
      homebrew = {
        enable = true;
        onActivation.cleanup = "check";
        onActivation.autoUpdate = false;
        onActivation.upgrade = true;
        greedyCasks = true;
        brews = [
          "immich-go"
          "apfel"
          "herdr"
          "pkgx"
          "dops"
          "mole"
          "FelixKratz/formulae/sketchybar"
          "asmvik/formulae/skhd"
          "asmvik/formulae/yabai"
          "gromgit/fuse/ext4fuse-mac"
          {
            name = "nextfire/tap/apple-music-discord-rpc";
            start_service = true;
          }
          "git-filter-repo"
          "mas"
          "media-control"
        ];
        casks = [
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
          #"swiftbar"
          #"nikitabobko/tap/aerospace"
          #"mediosz/tap/swipeaerospace"

          "google-chrome"
          "arc"
          "zen"
          #"brave-browser"
          "safe-exam-browser"

          "cursor"
          "codex"
          "lm-studio"
          "ollama-app"
          "orbstack"
          #"dbeaver-community"
          "iterm2"
          "hammerspoon"
          "visual-studio-code"
          "antigravity"
          "antigravity-ide"
          "claude"
          "chatgpt"
          "itermai"
          "mysqlworkbench"
          #"godot"
          "exo"
          "mochi-diffusion"
          "qmk-toolbox"
          #"raspberry-pi-imager"
          "balenaetcher"
          "icon-composer"

          "zoom"
          "slack"
          "telegram-a"
          "anydesk"
          "kde-connect"

          "discord"
          "vlc"
          "voicemod"
          "soulseek"
          "supertuxkart"

          "cold-turkey-blocker"
          "wakatime"
          "zotero"

          "sf-symbols"
          "bambu-studio"
        ];

        taps = map (name: {
          inherit name;
          trusted = !lib.hasPrefix "homebrew/" name;
        }) (builtins.attrNames config.nix-homebrew.taps);

        masApps = { };
      };

      environment.systemPath = lib.mkOrder 1100 [
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
      ];
    };
}
