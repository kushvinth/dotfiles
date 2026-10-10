# assets

Not linked into `$HOME` (nix/modules/home/dotfiles.nix only links `dot-config`, `dot-local/share` and `dot-agents`). Use this tree for files that do not map cleanly to `dot-config` or `dot-local`.

On Linux setups you might mirror system paths here, for example:

- `assets/configs/etc/` → `/etc` (on macOS: `environment.etc` via nix/modules/darwin/etc.nix)
- `assets/configs/home/user/` → `$HOME` extras outside `dot-config`
- `assets/configs/etc/zshenv` → optional `/etc/zshenv` snippet for `ZDOTDIR`
- `assets/scripts/` → build or install helpers

On macOS, most app config lives under `dot-config/`; add only what lives outside those trees.
