# macOS-specific user configuration.
{
  pkgs,
  ...
}:
{
  imports = [
    ./secrets.nix
    ./mas.nix
    ./completions.nix
    ./dotfiles.nix
    ./doctor.nix
  ];

  home.packages = with pkgs; [
    duti
    tsui
    # The Linux VM behind `dev` (dot-agents/dev/lima.yaml). Runs on vz;
    # stock wrapper only adds qemu (800 MiB) to PATH.
    (lima.override { qemu = emptyDirectory; })
  ];
}
