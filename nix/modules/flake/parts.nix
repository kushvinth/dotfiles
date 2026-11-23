{ inputs, lib, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-parts.flakeModules.easyOverlay
  ];

  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      # treefmt wrapper around nixfmt (`nix fmt` on a directory with plain
      # nixfmt is deprecated). CI runs `nix fmt -- --ci`.
      formatter = pkgs.nixfmt-tree;

      # Darwin CI builds all in-repo packages via `checks.aarch64-darwin`.
      checks = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin config.packages;
    };
}
