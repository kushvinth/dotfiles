# Nix (nix-darwin + Home Manager)

Thin linker layer: deploys existing repo trees without re-writing config in Nix.

| Repo path | Installed to | Module |
|-----------|--------------|--------|
| `assets/configs/etc/*` | `/etc/*` | `modules/darwin/etc.nix` (auto `readDir`) |
| `dot-config/*` (each subdir) | `~/.config/*` | `modules/home/dotfiles.nix` (auto `readDir`) |
| `dot-local/share/*` | `~/.local/share/*` | same |

Add a new app: create `dot-config/myapp/` or drop a file under `assets/configs/etc/`, then rebuild.

## Apply

```bash
sudo darwin-rebuild switch --flake ~/dotfiles/nix#MacbookPro
```

nix-darwin 25.05+ runs system activation as root (same idea as `nixos-rebuild`). Home Manager still applies to `system.primaryUser` (`MacbookPro` in `hosts/MacbookPro.nix`).

## Layout

```
nix/
├── flake.nix
├── lib/
│   ├── paths.nix       # repoRoot, dotConfig, assetsEtc, …
│   └── link-tree.nix   # readDir → link attrs
├── modules/
│   ├── darwin/         # system, /etc, homebrew, activation
│   └── home/           # dot-config + dot-local yoink
└── hosts/
    └── MacbookPro.nix  # username, toggles
```

## Bootstrap chain (zsh)

1. `/etc/zshenv` ← `assets/configs/etc/zshenv` (`ZDOTDIR`)
2. `~/.config/zsh` ← `dot-config/zsh` (out-of-store symlink by default)
3. `dot-config/zsh/.zshenv` adds `/run/current-system/sw/bin` to `PATH`

## Dev vs store copies

`dotfiles.useOutOfStoreSymlinks` (default `true`) symlinks `~/.config/*` and `~/.local/share/*` from **`dotfiles.repoRoot`** (default `~/dotfiles`), not from the flake’s `/nix/store/...-source` tree. Edit files under `dot-config/` and open a new shell (or run `zshrc`) — no rebuild.

Set `useOutOfStoreSymlinks = false` for immutable store copies (CI / pure eval).

**Still needs `darwin-rebuild switch`:** Nix/Homebrew packages, `/etc/*` from `assets/configs/etc`, git submodules on activation, and the one-time switch after changing linker options.

## Also runs on switch

- `git submodule update --init --recursive` (zsh plugins)
- `brew bundle install --file Brewfile` (disable with `dotfiles.brewBundle = false`)

## Legacy install

Linux / non-Nix: `make stow` and `make etc` from the repo root still work.
