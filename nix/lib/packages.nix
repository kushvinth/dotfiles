# Pure package set definitions (pkgs -> [ package ]).
# Shared across Home Manager and NixOS configurations without module-type collisions.
{
  core =
    pkgs: with pkgs; [
      bat
      btop
      curl
      direnv
      duf
      eza
      fastfetch
      fd
      git
      git-lfs
      gnupg
      jq
      lazygit
      delta
      lsd
      ncdu
      neovim
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
    ];

  dev =
    pkgs: with pkgs; [
      # Dev tools & runtimes
      cloc
      deno
      entr
      markdownlint-cli
      nix-output-monitor
      nixfmt
      perl
      pre-commit
      ruby
      simdjson
      sqlite
      uv
      zig
      zizmor

      # Containers & infrastructure
      docker
      docker-compose
      lazydocker
      nginx
      podman
      postgresql
      terraform

      # Network utilities
      gping
      nmap
      openssl
      socat
      sshpass

      # Media & misc
      ffmpeg
      imagemagick
      qmk
      yt-dlp

      # Backups
      borgbackup
      borgmatic

      # Go toolchain
      air
      go
      gofumpt
      golangci-lint
      gosec
      govulncheck

      # Rust toolchain
      cargo
      clippy
      rust-analyzer
      rustc
      rustfmt

      # JavaScript / TypeScript toolchain
      eslint
      nodejs
      pnpm
      prettier
      typescript
      yarn

      # AI Agent tooling & helpers
      claude-code
      ccusage
      rtk
      bun
      ast-grep
      difftastic
      gitleaks
      hyperfine
      sd
      pi-coding-agent
      shellcheck
      shfmt
      yq-go

      # Language servers
      gopls
      lua-language-server
      pyright
      typescript-language-server

      # In-repo packages (nix/packages)
      gnhf
    ];
}
