# The system every `dev` container boots (sudoAlphaX's /var/lib/machines/dev-<uid>
# template, as a NixOS closure). Built inside the dev-vm config, so its store
# paths are shared with the VM and bound read-only into each container.
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
  tools = "/nix/var/nix/profiles/dev/tools";
in
{
  boot.isContainer = true;
  system.stateVersion = "26.05";

  users.users.dev = {
    uid = 501;
    group = "users";
    home = "/home/dev";
    createHome = true;
    shell = pkgs.zsh;
    linger = true;
  };

  environment.systemPackages =
    dotfilesLib.packages.core pkgs
    ++ [
      pkgs.ghostty.terminfo
      nixLocate
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

      zsh
      oh-my-zsh
      fzf
      gping

      gh
      python3
      uv
      nodejs
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
      ollama

      gopls
      lua-language-server
      pyright
      typescript-language-server

      nix
    ]);

  environment.profiles = lib.mkOrder 2000 [ tools ];

  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    shellInit = ''
      [[ :$PATH: == *:/run/current-system/sw/bin:* ]] || PATH=$PATH:/run/current-system/sw/bin
      command_not_found_handler() {
        [[ -n $_dev_cnf ]] && { print -u2 "zsh: command not found: $1"; return 127; }
        local _dev_cnf=1
        local p=''${''${(f)"$(${nixLocate}/bin/nix-locate --minimal --whole-name --at-root "/bin/$1" 2>/dev/null)"}[1]}
        p=''${p%.out}
        if [[ -z $p ]]; then
          print -u2 "zsh: command not found: $1"
        elif [[ -t 0 && -t 2 ]] && read -q "?$1 is in nixpkgs#$p. Install it for every dev container? [y/N] " </dev/tty 2>/dev/tty; then
          print -u2
          NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure --profile ${tools} "nixpkgs#$p" && rehash && "$@"
          return
        else
          [[ -t 0 && -t 2 ]] && print -u2
          print -u2 "$1: not installed. It is nixpkgs#$p; install for every dev container with: NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure --profile ${tools} nixpkgs#$p"
        fi
        return 127
      }
    '';
  };

  environment.variables = {
    ZDOTDIR = "/home/dev/.config/zsh";
    HISTFILE = "/home/dev/.cache/zsh_history";
    EDITOR = "nvim";
    CLAUDE_CONFIG_DIR = "/home/dev/.claude";
    UV_PROJECT_ENVIRONMENT = ".venv-linux";
    NIX_REMOTE = "daemon";
    OLLAMA_HOST = "http://192.168.5.2:11434";
    MAGNITUDE_HOST = "http://127.0.0.1:10100";
    OPENAI_BASE_URL = "http://127.0.0.1:10100/inference/v1";
    SEARXNG_URL = "http://100.64.0.24:8980";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    ZELLIJ_CONFIG_DIR = "/home/dev/.agents/dev/zellij";
  };

  systemd.tmpfiles.rules = [
    "L+ /home/dev/.oh-my-zsh - - - - ${pkgs.oh-my-zsh}/share/oh-my-zsh"
    "d /home/dev/.config/opencode 0755 dev users -"
    "L+ /home/dev/.config/opencode/opencode.jsonc - - - - /home/dev/.dots/dot-config/opencode/opencode.jsonc"
    "L+ /home/dev/.config/opencode/skills - - - - /home/dev/.dots/dot-config/opencode/skills"
    "L+ /home/dev/.config/opencode/command - - - - /home/dev/.dots/dot-config/opencode/command"
  ];

  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    sandbox.enabled = false;
    permissions.defaultMode = "bypassPermissions";
    skipDangerousModePermissionPrompt = true;
  };

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

  networking = {
    useDHCP = false;
    useHostResolvConf = true;
    firewall.enable = false;
  };

  programs.nix-ld.enable = true;
  environment.etc."claude-code/CLAUDE.md".source = ./AGENTS.md;

  services.journald.settings.Journal = {
    Storage = "volatile";
    RuntimeMaxUse = "16M";
  };

  nix.enable = false;
  environment.etc."nix/nix.conf".text = "experimental-features = nix-command flakes\n";
  environment.etc."nix/registry.json".text = builtins.toJSON {
    version = 2;
    flakes = [
      {
        from = {
          type = "indirect";
          id = "nixpkgs";
        };
        to = {
          type = "path";
          path = "${inputs.nixpkgs}";
        };
      }
    ];
  };
}
