# This machine

- macOS (Apple Silicon), managed by nix-darwin + home-manager. The flake is `~/dotfiles/nix`.
- Installing things:
  - CLI tools: `home.packages` in `~/dotfiles/nix/modules/home/default.nix`
  - GUI apps, or tools scripts call via `/run/current-system/sw`: `nix/modules/darwin/system.nix`
  - Casks and brews: `nix/modules/darwin/homebrew.nix`
  - Don't `brew install` or `npm i -g` ad hoc: activation aborts on undeclared Homebrew packages.
- One-off tool without installing it: `, <cmd>` (comma) or `nix run nixpkgs#<pkg>`.
- Applying changes needs `darnix` (`nh darwin switch`, sudo + Touch ID). Ask me to run it; don't run it yourself.
- Configs are linked from `~/dotfiles` by Home Manager on every switch (`nix/modules/home/dotfiles.nix`): each git-tracked entry of `dot-config/` → `~/.config/`, while `~/.agents/` is one live link to all of `dot-agents/`, untracked files included.
- `~/dotfiles` is a **public** repo: never write secrets there. Secrets live in the macOS Keychain, declared in `nix/modules/home/secrets.nix` (`secret run <VAR> -- <cmd>`, Touch ID per use).
- **Notify me** on a long/unattended run finishing (build, tests, deploy, agent loop) with `~/.agents/bin/notify.sh "<title>" "<message>"` (Gotify push; see the `agent-notify` skill). Claude Code, Codex and opencode already push when a session stops — don't double up.

## Tools

- Python: `uv` (`uv run`, `uv add`).
- Search: `rg`, `fd`. Structural search/rewrite: `ast-grep run -p '<pattern>' -l <lang>`.
- JSON `jq`, YAML `yq`, find-and-replace `sd`, structural diffs `difft`.
- Before pushing a public repo: `gitleaks git` or `gitleaks dir`.

## Spend fewer tokens

- Read the part of a file you need (line ranges, `rg -n`), not whole files; don't re-read a file you just wrote.
- Keep command output short: `--quiet`, `| tail`, `git diff --stat` before the full diff.
- Smallest change that does the job: reuse what the repo has, stdlib before a dependency, no speculative abstractions.
- Short answers: the result and what I need to do, not a narration of the steps.
