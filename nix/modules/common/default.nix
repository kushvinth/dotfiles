# Platform-agnostic Nix daemon configuration.
# Imported by both darwinConfigurations and nixosConfigurations.
{ ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
