# dotfiles

```bash
git clone --recurse-submodules … ~/dotfiles
cd ~/dotfiles
make install
brew bundle install --file ./Brewfile
make setup   # optional
```

Or: `stow -v --dotfiles .` (see `.stowrc`). Run `make help` for all targets.

See [dot-config/USAGE.md](dot-config/USAGE.md).
