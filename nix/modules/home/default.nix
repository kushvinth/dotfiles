{
  pkgs,
  user,
  ...
}:
{
  imports = [
    ./dotfiles.nix
  ];

  home.username = user;
  home.stateVersion = "24.11";
  home.homeDirectory = "/Users/${user}";

  # Your CLI tools: add new nixpkgs packages here. GUI apps and anything the
  # system or scripts need stay in nix/modules/darwin/system.nix (see there).
  home.packages = with pkgs; [
    # Shell & files
    bat
    btop
    duf
    eza
    fastfetch
    fd
    lsd
    ncdu
    ripgrep
    starship
    tldr
    tmux
    tree
    watch
    wget
    yazi
    zellij
    zoxide

    # Dev tools
    cloc
    deno
    entr
    git-lfs
    gnupg
    lazygit
    markdownlint-cli
    neovim
    nixfmt
    perl
    pre-commit
    ruby
    simdjson
    sqlite
    stow
    uv
    zig
    zizmor

    # Containers & infra
    docker
    docker-compose
    lazydocker
    nginx
    podman
    postgresql
    terraform

    # Network
    gping
    nmap
    openssl
    socat
    sshpass

    # Media & misc
    duti
    ffmpeg
    imagemagick
    qmk
    yt-dlp

    # Backups (the scheduled run is nix/modules/darwin/backup.nix)
    borgbackup
    borgmatic

    # Go
    air
    go
    gofumpt
    golangci-lint
    gosec
    govulncheck

    # Rust
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt

    # JavaScript
    eslint
    nodejs
    pnpm
    prettier
    typescript
    yarn

    # Claude Code + the tools it reaches for
    claude-code
    ccusage # token/cost reports from ~/.claude transcripts
    ast-grep # structural search/rewrite (`ast-grep run -p ... -l ...`)
    difftastic # syntax-aware diffs (`difft`)
    gitleaks # secret scan before pushing (this repo is public)
    hyperfine
    sd
    shellcheck
    shfmt
    yq-go
    # Language servers for the Claude Code *-lsp plugins (rust-analyzer is under Rust)
    gopls
    lua-language-server
    pyright
    typescript-language-server

    # Our own packages (nix/packages)
    tsui
  ];
}
