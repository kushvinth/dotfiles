{
  config,
  lib,
  paths,
  link-tree,
  ...
}:
let
  useOoS = config.dotfiles.useOutOfStoreSymlinks;

  mkSource =
    path:
    if useOoS then
      config.lib.file.mkOutOfStoreSymlink path
    else
      builtins.path {
        path = path;
        name = "dotfile";
      };

  configDirs = link-tree.linkDirs {
    root = paths.dotConfig;
    mkEntry = path: {
      source = mkSource path;
      force = true;
    };
  };

  localDirs = link-tree.linkDirs {
    root = paths.dotLocalShare;
    mkEntry = path: {
      source = mkSource path;
      force = true;
    };
  };

  localFiles = lib.mapAttrs' (name: entry: {
    name = ".local/share/${name}";
    value = entry;
  }) localDirs;
in
{
  options.dotfiles = {
    useOutOfStoreSymlinks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Symlink configs from the live repo checkout (recommended on macOS).";
    };
  };

  config = {
    xdg.configFile = configDirs;
    home.file = localFiles;
  };
}
