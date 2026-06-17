# Generic readDir → attrset of { source = ...; } entries (no per-app listing).
{ lib }:

{
  linkDirs =
    {
      root,
      mkEntry,
    }:
    let
      entries = builtins.readDir root;
      dirNames = lib.attrNames (lib.filterAttrs (_: type: type == "directory") entries);
    in
    lib.genAttrs dirNames (name: mkEntry "${root}/${name}");

  linkFiles =
    {
      root,
      mkEntry,
    }:
    let
      entries = builtins.readDir root;
      fileNames = lib.attrNames (lib.filterAttrs (_: type: type == "regular") entries);
    in
    lib.genAttrs fileNames (name: mkEntry "${root}/${name}");
}
