@~/.agents/AGENTS.md

# Claude Code only

The shared rules above are `dot-agents/AGENTS.md` (Codex, opencode and Gemini read the same file). This file lives in `dot-config/claude/`; put Claude-only notes here.

## Config

- `~/.claude/{settings.json,CLAUDE.md,statusline.sh,hooks}` are read-only Nix store links to `dot-config/claude/`: `/config`, `claude config set` and Orca can't write them. Edit the repo file, then `darnix`.
- Home Manager links every entry in `dot-config/claude/` (`nix/modules/home/dotfiles.nix`), so keep stray files (`*.bak`) out of it.
- Plugins: declare them in `enabledPlugins` (and the marketplace in `extraKnownMarketplaces`), then `claude plugin install <name>@<marketplace>` to fetch them. The `*-lsp` plugins use language servers from `home.packages`.
- Model: the default is `sonnet`; effort per model is set in `modelSettings`.
- Seatbelt sandbox: `sandbox` in settings.json (`enabled` sets the default; `/sandbox` toggles it per session). `nix`, `nh`, `gh`, `limactl` and `docker` always run outside it.
- Never read `~/.claude.json`, `.credentials.json`, `auth.json` or `.env*`; deny rules block most of them, but don't route around them with Bash.

## Hooks already running (don't duplicate their work)

- `rtk hook claude` (PreToolUse, Bash) rewrites commands through RTK to save tokens. Don't add `rtk` yourself.
- `hooks/format.sh` (after Edit/Write):
  - formats `.nix`, `.go`, `.sh` (only under an `.editorconfig`) and `.py` (only under a `pyproject.toml` or `ruff.toml`)
  - a nixfmt parse error comes back as a hook error: fix it before moving on
- `notify.sh` pushes on Stop and Notification: only notify by hand for runs that outlive the session.
- The long inline `ORCA_*` hooks belong to Orca.app and do nothing outside it. Leave them.

## Skills and plugins

- Skills come from `dot-agents/skills` (the `kushvinth/skills` submodule), linked as `~/.claude/skills/<name>`. `dot-agents/bin/skills-audit` writes `docs/skills-audit.md`, which lists what each agent sees.
- Prefer the `gnhf-rounds` skill to hand off well-scoped, independent coding tasks to opencode agents.
- Library or API docs: the `context7` MCP before guessing from memory.
- `ponytail` is on (default level in `dot-config/ponytail/config.json`). `/ponytail lite|full|ultra` switches it.

## `dev` containers

- Claude inside `dev` uses shared state in the VM (`/var/lib/dev/state/claude`), with its own plugins and logins. `vmdev up` regenerates its settings from this repo on each start.
- `dev` syncs chats both ways with `~/.claude/projects`, so `claude --resume` on the Mac sees container sessions. Only transcripts sync, never `memory/` or config.
- Nothing in the VM may write to the Mac's `~/.claude`. Keep it that way when changing `dev` (`dot-config/zsh/.zshalias`, `nix/hosts/dev-vm/`).

## Usage

- Cost and tokens: `ccusage`.
- The statusline shows dir, branch, model, context %, the 5h limit and, once it passes 50%, the 7d limit.
- Transcripts are in `~/.claude/projects/` and plans in `~/.claude/plans/`.
