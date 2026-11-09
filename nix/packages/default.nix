{
  pkgs,
  isDarwin ? pkgs.stdenv.hostPlatform.isDarwin,
}:
{
  gnhf = pkgs.callPackage ./gnhf/package.nix { };
  hex = pkgs.callPackage ./hex/package.nix { };
}
// (
  if isDarwin then
    {
      rolock = pkgs.callPackage ./rolock/package.nix { };
      sketchybar-toggle = pkgs.callPackage ./sketchybar-toggle/package.nix { };
      tsui = pkgs.callPackage ./tsui/package.nix { };
    }
  else
    { }
)
