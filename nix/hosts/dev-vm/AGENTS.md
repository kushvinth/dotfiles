# You are in a dev container, not on the Mac

- NixOS (aarch64, no GPU) in a systemd-nspawn container, inside the user's always-on Lima VM, started by `dev` on the Mac (`nix/hosts/dev-vm` in `~/dotfiles`).
- Ignore the Mac-only parts of `~/.agents/AGENTS.md`: `darnix`, Homebrew, `secret`/Keychain, `notify.sh`, nix-darwin paths. Its tool and token-saving rules still apply.
- The project in `~/` is the user's Mac folder, shared live: every edit lands on the Mac at once. Outside it, only `~/.cache`, `~/.local/share`, `~/.local/state`, `~/go`, `~/.npm`, `~/.config/gh` and the agent dirs (`~/.claude`, `~/.codex`) persist; `~/.local/bin` does not; the rest is thrown away when the container stops.
- You are `dev` (uid 501): no sudo, no root, `/nix/store` read-only. Don't try to get around that.
- Missing tool:
  - for every dev container (persists, same nixpkgs as the Mac): `NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure --profile /nix/var/nix/profiles/dev/tools nixpkgs#<pkg>`
  - one-off: `nix shell nixpkgs#<pkg> -c <cmd>`
  - which package has a command: `nix-locate --minimal --whole-name --at-root /bin/<cmd>`
- Python: `uv` (`uv venv`, `uv pip`, `uv run`; `uv python install 3.11` for another version). Node: `node`, `npm`.
- Prebuilt Linux binaries and wheels run (nix-ld).
- Ports: a server listening on any port here is reachable from the Mac at `http://localhost:<port>` (Lima forwards it). Containers share the VM's network, so a port another project already uses is taken: pick another. Tell the user the URL.
- Network: the internet works; the Mac, the LAN and link-local addresses are blocked on purpose, except these Mac services:
  - Ollama at `http://192.168.5.2:11434`, also proxied to `http://localhost:11434` (`OLLAMA_HOST` is set; OpenAI-compatible API at `/v1`). The `ollama` CLI (`ollama list`, `ollama run`) uses the Mac's server and models.
  - SearXNG web search at `http://100.64.0.24:8980` (`SEARXNG_URL` is set; `/search?q=...&format=json`), on the user's homelab over Tailscale; nothing else on the tailnet is reachable
  - Jupyter at `http://100.64.0.27:8888` (`/lab`), on the tailnet
  - whisper-server (speech-to-text) at `http://192.168.5.2:8080`. Don't serve your own app on 8080: the Mac's is taken, so it can't be forwarded.
- No GPU here. LLM inference: use the Mac's Ollama above. Training or other GPU work (PyTorch MPS, MLX, CUDA) can't run in this container: tell the user it needs to run on the Mac. Never pull or delete Ollama models without asking: they live on the Mac's disk.
