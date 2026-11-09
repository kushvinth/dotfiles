# macOS GUI applications installed via nix-darwin.
# nix-darwin links these into /Applications/Nix Apps so they are indexed by Spotlight/Raycast.
{ pkgs, ... }:
{
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
  ];
}
