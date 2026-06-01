# assets

Not deployed by GNU Stow. Use this tree for files that do not map cleanly to `dot-config` or `dot-local`.

On Linux setups you might mirror system paths here, for example:

- `assets/configs/etc/` → `/etc` (often via a separate install step or `stow -t /` with care)
- `assets/configs/home/user/` → `$HOME` extras outside `dot-config`
- `assets/configs/etc/zshenv` → optional `/etc/zshenv` snippet for `ZDOTDIR`
- `assets/scripts/` → build or install helpers

On macOS, most app config lives under `dot-config/`; add only what you install outside Stow.
