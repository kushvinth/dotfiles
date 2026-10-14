# The base every `dev` container boots with: what your zsh config, zellij,
# nvim and the agents need. Everything else installs on first use: run a
# missing command and the container offers it (container.nix), at the same
# nixpkgs as the Mac. Lives once in the VM's /nix/store, bound read-only.
pkgs: with pkgs; [
  # userland (the Mac has these from macOS)
  coreutils
  findutils
  gnugrep
  gnused
  gawk
  gnutar
  gzip
  unzip
  curl
  less
  which
  procps
  man
  glibc.bin # iconv (omz_urlencode)

  # your zsh (.zshrc plugins, starship, aliases)
  zsh
  oh-my-zsh
  fzf
  zoxide
  direnv
  starship
  bat
  eza

  # editor + git
  zellij
  neovim
  lazygit
  git
  gh
  delta

  # search
  ripgrep
  fd
  jq

  # what agents reach for first
  python3
  uv
  nodejs

  # agents
  claude-code
  codex
  rtk
  gnhf # nix/packages/gnhf (the gnhf-rounds skill)

  # servers for the Claude Code *-lsp plugins (as on the Mac, home/default.nix)
  gopls
  lua-language-server
  pyright
  rust-analyzer
  typescript-language-server

  # installs the rest on demand, through the VM's nix daemon
  nix
]
