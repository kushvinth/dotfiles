# custom (ZSH_CUSTOM)

Oh My Zsh custom directory. Plugins are git submodules (see `.gitmodules` at repo root) under `plugins/`.

Clone this repo with submodules:

```bash
git clone --recurse-submodules …
# or after clone:
git submodule update --init --recursive
```

`.zshrc` loads `zsh-autocomplete` and `zsh-syntax-highlighting` from here; OMZ loads `forgit` and `you-should-use` via the `plugins=(…)` array.
