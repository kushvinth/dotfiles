# Universal zsh completions that no package ships by default.
{
  lib,
  pkgs,
  ...
}:
let
  extraCompletions = pkgs.runCommand "zsh-completions-common" { } ''
    dir=$out/share/zsh/site-functions
    mkdir -p $dir
    # nixpkgs' uv only ships the completion for uv itself.
    HOME=$TMPDIR ${lib.getExe' pkgs.uv "uvx"} --generate-shell-completion zsh > $dir/_uvx
  '';
in
{
  home.packages = [ extraCompletions ];
}
