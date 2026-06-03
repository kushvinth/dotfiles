# Repo paths relative to the flake root (nix/).
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
