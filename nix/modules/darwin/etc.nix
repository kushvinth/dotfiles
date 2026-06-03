{
  config,
  lib,
  paths,
  link-tree,
  ...
}:
let
  etcFiles = link-tree.linkFiles {
    root = paths.assetsEtc;
    mkEntry = path: {
      source = path;
    };
  };
in
{
  environment.etc = etcFiles;
}
