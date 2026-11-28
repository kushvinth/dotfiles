# What every `dev` microVM runs (user, tools, agents, shell), independent of
# how it boots (guest.nix).
# Nothing here may depend on the project: one closure serves every project.
{
  pkgs,
  lib,
  inputs,
  dotfilesLib,
  ...
}:
let
  nixLocate =
    inputs.nix-index-database.packages.${pkgs.stdenv.hostPlatform.system}.nix-index-with-small-db;

  # Only what the guest enforces: the VM is the sandbox, so Claude's own is
  # off and it doesn't ask. Your Mac settings (hooks, deny rules, statusline,
  # plugins) arrive live as ~/.claude/settings.json (dev-claude-sync), so a
  # settings.json edit needs only `dev stop && dev`, not a rebuild.
  managedSettings = {
    sandbox.enabled = false;
    permissions.defaultMode = "bypassPermissions";
    skipDangerousModePermissionPrompt = true;
  };

  # ~/.claude/settings.json = the Mac's dot-config/claude/settings.json (from
  # this boot's dotfiles copy) minus the `ask` rules, which prompt even in
  # bypassPermissions; and /workspace trusted, so Claude doesn't ask (once
  # signed in, i.e. there is a .claude.json; skipped while a Claude runs, as it
  # rewrites that file too). Runs at boot and on every `dev`.
  claudeSync = pkgs.writeShellApplication {
    name = "dev-claude-sync";
    runtimeInputs = with pkgs; [
      jq
      coreutils
      procps
    ];
    text = ''
      dir=''${CLAUDE_CONFIG_DIR:-$HOME/.claude}
      src=$HOME/.dots/dot-config/claude/settings.json
      if [ -r "$src" ] && [ -d "$dir" ]; then
        jq 'del(.permissions.ask)' "$src" >"$dir/settings.json.tmp" &&
          mv -f "$dir/settings.json.tmp" "$dir/settings.json"
      fi
      json=$dir/.claude.json
      if [ -s "$json" ] && ! pgrep -u "$(id -u)" '^\.?claude(-wrapped)?$' >/dev/null &&
        ! jq -e '.projects["/workspace"].hasTrustDialogAccepted' "$json" >/dev/null; then
        jq '.projects["/workspace"].hasTrustDialogAccepted = true' "$json" >"$json.tmp" &&
          chmod 600 "$json.tmp" && mv -f "$json.tmp" "$json"
      fi
    '';
  };

  # Run by devctl at the start of every `dev` session: git identity from the
  # Mac (GIT_AUTHOR_* via ssh SetEnv) into ~/.gitconfig, and the Claude sync.
  sessionInit = pkgs.writeShellApplication {
    name = "dev-session-init";
    runtimeInputs = [
      pkgs.git
      claudeSync
    ];
    text = ''
      if [ -n "''${GIT_AUTHOR_NAME:-}" ]; then git config --global user.name "$GIT_AUTHOR_NAME"; fi
      if [ -n "''${GIT_AUTHOR_EMAIL:-}" ]; then git config --global user.email "$GIT_AUTHOR_EMAIL"; fi
      dev-claude-sync || true
    '';
  };
in
{
  system.stateVersion = "26.05";
  nixpkgs.config.allowUnfree = true;

  users.users.dev = {
    uid = 501;
    group = "users";
    home = "/home/dev";
    createHome = true;
    shell = pkgs.zsh;
    linger = true;
    # No wheel, no sudo (guest.nix): dev is the only login and has no way up.
    extraGroups = lib.mkForce [ ];
  };

  environment.systemPackages =
    dotfilesLib.packages.core pkgs
    ++ [
      pkgs.ghostty.terminfo
      nixLocate
      claudeSync
      sessionInit
    ]
    ++ (with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      gnutar
      gzip
      unzip
      less
      which
      procps
      man
      glibc.bin
      iproute2

      zsh
      oh-my-zsh
      fzf
      gping

      # Baseline toolchains (Rust from nixpkgs, not rustup)
      gh
      python3
      uv
      nodejs
      pnpm
      go
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer
      gcc
      gnumake
      cmake
      pkg-config

      # Agents
      claude-code
      codex
      opencode
      rtk
      gnhf

      asciinema
      asciinema-agg
      ffmpeg-headless

      playwright-mcp
      playwright-driver.browsers

      # Language servers
      gopls
      lua-language-server
      pyright
      typescript-language-server
    ]);

  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    shellInit = ''
      [[ :$PATH: == *:/run/current-system/sw/bin:* ]] || PATH=$PATH:/run/current-system/sw/bin
      # Missing command: say which nixpkgs package has it. Installing is up to
      # the project (flake + direnv) or a one-off `nix shell`.
      command_not_found_handler() {
        local p=''${''${(f)"$(${nixLocate}/bin/nix-locate --minimal --whole-name --at-root "/bin/$1" 2>/dev/null)"}[1]}
        p=''${p%.out}
        if [[ -n $p ]]; then
          print -u2 "$1: not installed. Try: nix shell nixpkgs#$p -c $1   (or add it to the project's flake)"
        else
          print -u2 "zsh: command not found: $1"
        fi
        return 127
      }
    '';
  };

  environment.variables = {
    ZDOTDIR = "/home/dev/.config/zsh";
    HISTFILE = "/home/dev/.history/zsh_history";
    EDITOR = "nvim";
    CLAUDE_CONFIG_DIR = "/home/dev/.claude";
    UV_PROJECT_ENVIRONMENT = ".venv-linux";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    ZELLIJ_CONFIG_DIR = "/home/dev/.agents/dev/zellij";
  };

  systemd.tmpfiles.rules = [
    "L+ /home/dev/.oh-my-zsh - - - - ${pkgs.oh-my-zsh}/share/oh-my-zsh"
    "d /home/dev/.config 0755 dev users -"
    "d /home/dev/.local 0755 dev users -"
    "d /home/dev/.local/share 0755 dev users -"
    "d /home/dev/.config/opencode 0755 dev users -"
    "L+ /home/dev/.config/opencode/opencode.jsonc - - - - /home/dev/.dots/dot-config/opencode/opencode.jsonc"
    "L+ /home/dev/.config/opencode/skills - - - - /home/dev/.dots/dot-config/opencode/skills"
    "L+ /home/dev/.config/opencode/command - - - - /home/dev/.dots/dot-config/opencode/command"
  ];

  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON managedSettings;
  environment.etc."claude-code/CLAUDE.md".source = ./guest-AGENTS.md;

  programs.git = {
    enable = true;
    lfs.enable = true;
    config.init.defaultBranch = "main";
    config.pull.rebase = false;
    config.core.excludesFile = "${pkgs.writeText "dev-gitignore" ".venv-linux/\n"}";
    config.credential = {
      "https://github.com".helper = "!gh auth git-credential";
      "https://gist.github.com".helper = "!gh auth git-credential";
    };
  };

  programs.nix-ld.enable = true;

  services.journald.settings.Journal = {
    Storage = "volatile";
    RuntimeMaxUse = "16M";
  };

  nix.channel.enable = false;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = lib.mkForce [ "root" ];
    # Only the pinned registry below: no download of the global one per command.
    flake-registry = "";
  };
  # `nix shell nixpkgs#…` uses the same nixpkgs as the Mac.
  nix.registry.nixpkgs.to = {
    type = "path";
    path = "${inputs.nixpkgs}";
  };
}
