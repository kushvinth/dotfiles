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
- gstack's `timeline-stop-hook` (Stop, `_gstack_source`) was added by its `./setup`, which writes straight into the repo's `settings.json` through the link: check `git diff` after rerunning it.
- The long inline `ORCA_*` hooks belong to Orca.app and do nothing outside it. Leave them.

## Skills and plugins

- Skills come from `dot-agents/skills` (the `kushvinth/skills` submodule), linked as `~/.claude/skills/<name>`. `dot-agents/bin/skills-audit` writes `docs/skills-audit.md`, which lists what each agent sees.
- Prefer the `gnhf-rounds` skill to hand off well-scoped, independent coding tasks to opencode agents.
- Library or API docs: the `context7` MCP before guessing from memory.
- `ponytail` is on (default level in `dot-config/ponytail/config.json`). `/ponytail lite|full|ultra` switches it.

## Skill router

Invoke the matching skill yourself when a request fits; don't wait for a slash command. Skip it for quick questions, small scoped edits, or when I ask for a direct answer. gstack is a clone at `~/.claude/skills/gstack` (`./setup --host claude` registers `gstack-*`).

| Request | Skill |
|---|---|
| new idea, "is this worth building" | `gstack-office-hours` |
| spec it, write a ticket | `gstack-spec` |
| plan review: scope / architecture / UI / API | `gstack-plan-ceo-review` / `-eng-` / `-design-` / `-devex-`, all: `gstack-autoplan` |
| bug, error, "why is this broken" | `gstack-investigate` |
| review a diff: small / before a PR | `code-review` / `gstack-review` |
| second opinion | `gstack-codex` |
| "does it work", test the app | `gstack-qa` (report only: `gstack-qa-only`) |
| security | `security-review` for the diff, `gstack-cso` for a full audit |
| whole-repo audit, bloat | `ponytail-audit`; code health: `gstack-health` |
| commit | `commit-commands:commit` |
| ship a real project (tests, changelog, PR) | `gstack-ship`; dotfiles: `commit-commands:commit-push-pr` |
| docs: write / after a release | `gstack-document-generate` / `gstack-document-release` |
| browser, screenshot, scrape | `gstack-browse` / `gstack-scrape` |
| UI design | `frontend-design`; design system: `gstack-design-consultation` |
| diagram | `archify`; isometric figure: `anatomy` |
| save / resume work across days | `gstack-context-save` / `gstack-context-restore` |
| several independent coding tasks | `gnhf-rounds` |
| stop a repeated mistake | `hookify:hookify` |
| weekly retro | `gstack-retro` |

Never route dotfiles work to `gstack-ship`, `land-and-deploy` or `canary`: this repo has no tests, VERSION or deploys.

## `dev` containers

- Claude inside `dev` uses shared state in the VM (`/var/lib/dev/state/claude`), with its own plugins and logins. `vmdev up` regenerates its settings from this repo on each start.
- `dev` syncs chats both ways with `~/.claude/projects` (on entry, then every minute until `dev stop` or the VM idles off), so `claude --resume` on either side sees the other's sessions. Only transcripts sync, never `memory/` or config.
- Nothing in the VM may write to the Mac's `~/.claude`. Keep it that way when changing `dev` (`dot-config/zsh/.zshalias`, `nix/hosts/dev-vm/`).

## Usage

- Cost and tokens: `ccusage`.
- The statusline shows dir, branch, model, context %, the 5h limit and, once it passes 50%, the 7d limit.
- Transcripts are in `~/.claude/projects/` and plans in `~/.claude/plans/`.
