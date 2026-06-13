# Repo paths relative to the flake root (nix/).
# Note: ${self}/.. resolves under /nix/store at eval time. Home Manager uses
# config.dotfiles.repoRoot (~/dotfiles) for live symlinks when useOutOfStoreSymlinks is on.
{ self }:

let
  repoRoot = "${self}/..";
in
{
  inherit repoRoot;
  dotConfig = "${repoRoot}/dot-config";
  dotLocalShare = "${repoRoot}/dot-local/share";
  assetsEtc = "${repoRoot}/assets/configs/etc";
  brewfile = "${repoRoot}/Brewfile";
}
