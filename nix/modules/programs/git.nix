{
  flake.modules.homeManager.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      email = "kushvinth.m@gmail.com";
      githubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYEHs5qpgSuR94xNpNaZ3cwqEgQcEM9aBUtAkq6+gh5 github";
      codebergKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDkX9QKTFapLVP/SI8yNWeBzUJMAAKlZC1+jAeMg+7Is codeberg";
      codeberg.contents.user.signingKey = "key::${codebergKey}";
    in
    {
      programs.git = {
        enable = true;
        package = lib.mkDefault pkgs.git;
        signing = {
          format = "ssh";
          key = "key::${githubKey}";
          signByDefault = true;
        };
        ignores = [ ".venv-linux/" ];
        includes = [
          (codeberg // { condition = "hasconfig:remote.*.url:https://codeberg.org/**"; })
          (codeberg // { condition = "hasconfig:remote.*.url:git@codeberg.org:*/**"; })
        ];
        settings.gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
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

      xdg.configFile."git/allowed_signers".text = ''
        ${email} ${githubKey}
        ${email} ${codebergKey}
      '';
    };
}
