# macOS-specific dotfile links (Library/Application Support and Hammerspoon).
{
  config,
  lib,
  inputs,
  ...
}:
let
  home = config.home.homeDirectory;
  src = "${inputs.self}/..";
  hasDir = d: builtins.pathExists "${src}/dot-config/${d}";

  darwinLinks =
    { }
    // lib.optionalAttrs (hasDir "Code") {
      "Library/Application Support/Code/User" = "${home}/.config/Code/User";
    }
    // lib.optionalAttrs (hasDir "lazygit") {
      "Library/Application Support/lazygit/config.yml" = "${home}/.config/lazygit/config.yml";
    }
    // lib.optionalAttrs (hasDir "hammerspoon") {
      ".hammerspoon" = "${home}/.config/hammerspoon";
    };
in
{
  home.file = lib.mapAttrs (_: path: {
    source = config.lib.file.mkOutOfStoreSymlink path;
  }) darwinLinks;
}
