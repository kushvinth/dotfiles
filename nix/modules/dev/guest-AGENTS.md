# You are in a dev microVM, not on the Mac

- NixOS (aarch64, no GPU) in a vfkit microVM of its own, one per project, started by `dev` on the Mac (`nix/modules/dev` in `~/dotfiles`). Every project's VM runs the same system.
- Ignore the Mac-only parts of `~/.agents/AGENTS.md`: `darnix`, Homebrew, `secret`/Keychain, `notify.sh`, nix-darwin paths. Its tool and token-saving rules still apply.
- `/workspace` is the user's project folder on the Mac, shared live: every edit lands on the Mac at once, and files you create belong to the user there.
- `/mnt/exchange` is a scratch folder the user can also see on the Mac (`~/.local/state/devvm/<id>/exchange`): put files there that they asked for and that don't belong in the project.
- What persists (this project's `/persist` volume): `~/.cache`, `~/.local/state`, `~/.local/share` (nvim plugins, pnpm store), `~/.npm`, `~/go`, `~/.cargo`, shell history, the agent dirs (`~/.claude`, `~/.codex`), `~/.config/gh`, and what you build or fetch with nix. Everything else, `~/.local/bin` included, is gone at the next boot. Other projects' VMs have their own volumes and sign-ins.
- `~/.dots` and the configs bound from it (`~/.config/zsh`, `nvim`, `starship`, `lazygit`, `~/.agents`) are a read-only copy of the user's dotfiles, refreshed at each boot. Don't try to edit them here.
- You are `dev` (uid 501): no sudo, no root, no wheel. Don't try to get around that.
- Missing tool:
  - for this project, kept: add it to the project's `flake.nix` dev shell and use direnv (`use flake`), or ask the user.
  - one-off: `nix shell nixpkgs#<pkg> -c <cmd>` (same nixpkgs as the Mac)
  - which package has a command: `nix-locate --minimal --whole-name --at-root /bin/<cmd>`
- Installed already: git, gh, rg, fd, jq, curl, neovim, tmux, zellij, node + pnpm, go, python3 + uv, Rust (rustc, cargo, clippy, rustfmt, rust-analyzer; from nixpkgs, no rustup), gcc, make, cmake, pkg-config, and LSPs.
- Python: `uv` (`uv sync`, `uv run`, `uv add`). The project's `.venv` belongs to the Mac (macOS binaries): never delete, recreate or run it. uv here uses `.venv-linux` (`UV_PROJECT_ENVIRONMENT`), git-ignored on both sides; `uv venv` without a path would still make `.venv`, so don't.
- Prebuilt Linux binaries and wheels run (nix-ld).
- Ports: tell the user to run `dev forward <port>` on the Mac; then a server here (even one on `localhost`) is at `http://localhost:<port>` there. Without it, a server on `0.0.0.0` is at `http://<vm-ip>:<port>` (`dev status` prints the IP). Other VMs can't reach it.
- The VM powers itself off after 10 minutes with nobody connected (30 if a detached zellij is left and idle), so don't leave long unattended work running without telling the user; `touch /persist/no-idle-stop` turns that off for this project.
- Network: the internet works. The Mac, the LAN, Tailscale, link-local addresses and other VMs are blocked on purpose, by the Mac's firewall and again in here. There are no Mac services (no Ollama, SearXNG or Jupyter). Don't try to get around that.
- No GPU here. Training or other GPU work (PyTorch MPS, MLX, CUDA) can't run in this VM: tell the user it needs to run on the Mac.
