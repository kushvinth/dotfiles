{ pkgs, ... }:
let
  pkgSets = import ../../../../lib/packages.nix;
in
{
  home.packages = pkgSets.core pkgs;
}
