# macOS-specific zsh completions (Homebrew and Tailscale App Store CLI).
{
  pkgs,
  inputs,
  ...
}:
let
  extraCompletions = pkgs.runCommand "zsh-completions-darwin" { } ''
    dir=$out/share/zsh/site-functions
    mkdir -p $dir
    # brew keeps its completion in the repo, not in share/ (brew-src is pinned
    # by nix-homebrew, so it matches the installed brew).
    cp ${inputs.nix-homebrew.inputs.brew-src}/completions/zsh/_brew $dir/
    # Tailscale's CLI comes with the App Store app; the nixpkgs build provides
    # its completion without a second CLI on PATH.
    cp ${pkgs.tailscale}/share/zsh/site-functions/_tailscale $dir/
  '';
in
{
  home.packages = [ extraCompletions ];
}
