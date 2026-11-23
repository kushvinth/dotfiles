{ inputs, ... }:
{
  flake.modules.homeManager.completions =
    {
      lib,
      pkgs,
      ...
    }:
    let
      completions = pkgs.runCommand "zsh-completions" { } ''
        dir=$out/share/zsh/site-functions
        mkdir -p $dir
        HOME=$TMPDIR ${lib.getExe' pkgs.uv "uvx"} --generate-shell-completion zsh > $dir/_uvx
        ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          cp ${inputs.nix-homebrew.inputs.brew-src}/completions/zsh/_brew $dir/
        ''}
      '';
    in
    {
      home.packages = [ completions ];
    };
}
