# zsh completions. .zshrc puts the nix profiles' site-functions on fpath
# (Homebrew's come from `brew shellenv`), so every switch brings completions in
# line with the installed packages. This adds the few that no package ships.
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  extraCompletions = pkgs.runCommand "zsh-completions-extra" { } ''
    dir=$out/share/zsh/site-functions
    mkdir -p $dir
    # brew keeps its completion in the repo, not in share/ (brew-src is pinned
    # by nix-homebrew, so it matches the installed brew).
    cp ${inputs.nix-homebrew.inputs.brew-src}/completions/zsh/_brew $dir/
    # Tailscale's CLI comes with the App Store app; the nixpkgs build provides
    # its completion without a second CLI on PATH.
    cp ${pkgs.tailscale}/share/zsh/site-functions/_tailscale $dir/
    # nixpkgs' uv only ships the completion for uv itself.
    HOME=$TMPDIR ${lib.getExe' pkgs.uv "uvx"} --generate-shell-completion zsh > $dir/_uvx
  '';
in
{
  home.packages = [ extraCompletions ];
}
