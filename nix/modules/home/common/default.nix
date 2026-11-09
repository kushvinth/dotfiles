# Platform-agnostic user configuration.
# Imported by both macOS and Linux / NixOS hosts.
{ ... }:
{
  imports = [
    ./packages/core.nix
    ./git.nix
    ./dotfiles.nix
    ./setup.nix
    ./doctor.nix
    ./secrets.nix
    ./completions.nix
  ];
}
