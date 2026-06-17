{
  config,
  lib,
  paths,
  link-tree,
  ...
}:
let
  useOoS = config.dotfiles.useOutOfStoreSymlinks;
  liveRoot = config.dotfiles.repoRoot;

  # paths.* use ${self}/.. which lives under /nix/store; mkOutOfStoreSymlink needs a real checkout path.
  toLivePath =
    path:
    "${liveRoot}/${lib.removePrefix "${paths.repoRoot}/" path}";

  mkSource =
    path:
    if useOoS then
      config.lib.file.mkOutOfStoreSymlink (toLivePath path)
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
    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/dotfiles";
      description = ''
        Live dotfiles checkout on disk (e.g. ~/dotfiles).
        Used when useOutOfStoreSymlinks is true so edits apply without rebuild.
        Override in the host module if the repo lives elsewhere.
      '';
    };

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
