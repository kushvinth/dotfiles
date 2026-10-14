{ ... }:
{
  # Written to ~/.config/git/config; ~/.gitconfig (identity, lfs) still loads
  # after it.
  programs.git = {
    enable = true;
    package = null; # git comes from nix/modules/darwin/system.nix
    signing.format = null; # no commit signing yet (docs/hardening.md)
    # By name, not store path: `gh auth setup-git` writes the store path into
    # ~/.gitconfig, which breaks after a GC (docs/hardening.md).
    settings.credential = {
      "https://github.com".helper = [
        ""
        "!gh auth git-credential"
      ];
      "https://gist.github.com".helper = [
        ""
        "!gh auth git-credential"
      ];
    };
  };
}
