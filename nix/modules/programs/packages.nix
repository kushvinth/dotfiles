{ dotfilesLib, ... }:
{
  flake.modules.homeManager.packages =
    { pkgs, lib, ... }:
    {
      home.packages =
        (dotfilesLib.packages.core pkgs)
        ++ (dotfilesLib.packages.dev pkgs)
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (
          (dotfilesLib.fonts pkgs)
          ++ (with pkgs; [
            # Linux GUI apps (matching macOS system/cask apps)
            obsidian
            zed-editor
            postman
            prismlauncher
            qbittorrent
            wireshark
            gitkraken
            neovide
            ghostty
            vscode
            discord
            slack
            vlc
            dbeaver-bin
            telegram-desktop
          ])
        );
    };
}
