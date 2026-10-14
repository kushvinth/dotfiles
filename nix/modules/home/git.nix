{ config, ... }:
let
  # Public halves only; the private keys stay in ~/.ssh, their passphrases in
  # the login Keychain (~/.ssh/config: UseKeychain).
  email = "kushvinth.m@gmail.com"; # same as ~/.gitconfig, which loads after this file
  githubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYEHs5qpgSuR94xNpNaZ3cwqEgQcEM9aBUtAkq6+gh5 github";
  codebergKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDkX9QKTFapLVP/SI8yNWeBzUJMAAKlZC1+jAeMg+7Is codeberg";
  codeberg.contents.user.signingKey = "key::${codebergKey}";
in
{
  # Written to ~/.config/git/config; ~/.gitconfig (identity, lfs) still loads
  # after it.
  programs.git = {
    enable = true;
    package = null; # git comes from nix/modules/darwin/system.nix
    # Every commit is signed through ssh-agent. `key::` inlines the public key
    # so git never reads ~/.ssh (blocked in agent sandboxes). GitHub's key is
    # the default; repos with a Codeberg remote switch to Codeberg's.
    signing = {
      format = "ssh";
      key = "key::${githubKey}";
      signByDefault = true;
    };
    includes = [
      (codeberg // { condition = "hasconfig:remote.*.url:https://codeberg.org/**"; })
      (codeberg // { condition = "hasconfig:remote.*.url:git@codeberg.org:*/**"; })
    ];
    settings.gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
    # delta (lazygit's diff view, `git diff | delta`): Catppuccin Mocha, like
    # Ghostty and bat. Layout flags live with each caller (dot-config/lazygit).
    settings.delta = {
      dark = true;
      syntax-theme = "Catppuccin Mocha";
      minus-style = "syntax #34293a";
      minus-emph-style = "bold syntax #53394c";
      plus-style = "syntax #2c3239";
      plus-emph-style = "bold syntax #404f4a";
      line-numbers-minus-style = "bold #f38ba8";
      line-numbers-plus-style = "bold #a6e3a1";
      line-numbers-zero-style = "#6c7086";
      line-numbers-left-style = "#6c7086";
      line-numbers-right-style = "#6c7086";
      hunk-header-line-number-style = "bold #a6adc8";
      file-style = "#cdd6f4";
      file-decoration-style = "#cdd6f4";
    };
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

  # Lets `git log --show-signature` verify these keys locally.
  xdg.configFile."git/allowed_signers".text = ''
    ${email} ${githubKey}
    ${email} ${codebergKey}
  '';
}
