{
  flake.modules.darwin.apps =
    { pkgs, ... }:
    {
      # GUI apps and system utilities linked into /Applications/Nix Apps
      environment.systemPackages = with pkgs; [
        gitkraken
        hex
        neovide
        obsidian
        postman
        prismlauncher
        qbittorrent
        wireshark
        zed-editor
        duti
        tsui
        (lima.override { qemu = emptyDirectory; })
      ];
    };
}
