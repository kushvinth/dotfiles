# Recursive readDir → attrset of { source = ...; } entries keyed by the path
# relative to `root` (e.g. "borgmatic/config.yaml"), so a whole tree such as
# assets/configs/etc maps 1:1 onto environment.etc.
{ lib }:

{
  linkFiles =
    {
      root,
      mkEntry,
    }:
    let
      walk =
        prefix:
        let
          entries = builtins.readDir "${root}/${prefix}";
          rel = name: if prefix == "" then name else "${prefix}/${name}";
        in
        lib.concatLists (
          lib.mapAttrsToList (
            name: type:
            if type == "regular" then
              [ (rel name) ]
            else if type == "directory" then
              walk (rel name)
            else
              [ ]
          ) entries
        );
    in
    lib.genAttrs (walk "") (relPath: mkEntry "${root}/${relPath}");
}
