# Usage

## macOS (Nix)

1. Clone the repo (e.g. `~/dotfiles`)
2. `sudo darwin-rebuild switch --flake ~/dotfiles/nix#MacbookPro`

See [nix/README.md](nix/README.md) for layout and options.

## Legacy / Linux (Stow)

1. Clone the repo in your `$HOME` directory
2. `cd` into the repo
3. `make install`
4. `brew bundle install --file ./Brewfile` (macOS)

