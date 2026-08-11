# Inspiration Repos & Skills

All repos referenced or forked in this project, plus available skills.

---

## Repos

### This Project

| Repo | Description |
|------|-------------|
| [ai-dot](https://github.com/tanishkadeep/landing-page) | K Studio - AI Consulting & Production Systems (main project) |
| [kushvinth.com](https://kushvinth.com) | Author's portfolio site |

### Forked / Embedded

| Repo | Location | Stack | Description |
|------|----------|-------|-------------|
| [nexxeln/nexxel.dev](https://github.com/nexxeln/nexxel.dev) | `startinspo/` | Next.js, Tailwind, TypeScript, MDX, Vercel | Personal site & blog template - used as inspiration for the portfolio/blog setup |
| [kunchenguid/gnhf](https://github.com/kunchenguid/gnhf) | `docs/gnhf/` | Node.js, TypeScript, ESM | "good night, have fun" - agent orchestrator that runs coding agents in a loop while you sleep |
| [tanishkadeep/landing-page](https://github.com/tanishkadeep/landing-page) | `docs/lol-git-backup/` | Next.js, Tailwind, TypeScript | Original landing page backup |
| [kushvinth/portfolio](https://kushvinth.com) | `docs/portfolio/` | Next.js, MDX, Bun | Portfolio site with blog posts and SEO implementation |
| [openai/skills](https://github.com/openai/skills) | `skills/` | Markdown, Shell | Agent Skills catalog for Codex - 39 curated + 5 system skills (pinned at `49f948f`) |

### Referenced in gnhf

| Repo | Description |
|------|-------------|
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | Autoresearch-style agent orchestration (gnhf is inspired by this) |
| [ghuntley.com/ralph](https://ghuntley.com/ralph/) | Ralph - the original overnight agent runner concept |
| [openclaw/acpx](https://github.com/openclaw/acpx) | ACP runtime and agent registry (bundled with gnhf) |
| [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) | AI-driven review/test/lint gate for git pushes |
| [github/copilot-cli](https://github.com/github/copilot-cli) | GitHub Copilot CLI (supported by gnhf as an agent) |

### Referenced in openai/skills

| Repo | Description |
|------|-------------|
| [openai/plugins](https://github.com/openai/plugins) | Current Codex skill and plugin examples (successor to skills repo) |
| [agentskills.io](https://agentskills.io) | Agent Skills open standard |

---

## Skills

### Available (opencode)

| Skill | Description |
|-------|-------------|
| `ralph-loop` | Start Ralph Loop - auto-continues a task until completion |
| `cancel-ralph` | Cancel active Ralph Loop |
| `help` | Explain Ralph Loop plugin and available commands |
| `customize-opencode` | Edit/create opencode configuration files (opencode.json, agents, skills, plugins, MCP servers) |

### Embedded (gnhf)

| Skill | Location | Description |
|-------|----------|-------------|
| `gnhf` | `docs/gnhf/skills/gnhf/SKILL.md` | Agent skill for running GNHF in Hands-Off or Companion mode - orchestrates long-running overnight coding sessions |

### Skills Directory (`skills/` - openai/skills clone)

#### Curated Skills (39)

| Skill | Description |
|-------|-------------|
| `aspnet-core` | ASP.NET Core development |
| `chatgpt-apps` | ChatGPT app development |
| `cli-creator` | CLI tool creation |
| `cloudflare-deploy` | Cloudflare deployment |
| `define-goal` | Goal definition and planning |
| `figma-code-connect-components` | Figma code connect components |
| `figma-create-design-system-rules` | Create Figma design system rules |
| `figma-create-new-file` | Create new Figma file |
| `figma-generate-design` | Generate Figma designs |
| `figma-generate-library` | Generate Figma libraries |
| `figma-implement-design` | Implement Figma designs |
| `figma-use` | Using Figma |
| `figma` | Figma integration |
| `gh-address-comments` | GitHub address comments |
| `gh-fix-ci` | Fix GitHub CI issues |
| `hatch-pet` | Hatch pet management |
| `jupyter-notebook` | Jupyter notebook operations |
| `linear` | Linear project management |
| `migrate-to-codex` | Migration to Codex |
| `netlify-deploy` | Netlify deployment |
| `notion-knowledge-capture` | Notion knowledge capture |
| `notion-meeting-intelligence` | Notion meeting intelligence |
| `notion-research-documentation` | Notion research documentation |
| `notion-spec-to-implementation` | Notion spec to implementation |
| `openai-docs` | OpenAI documentation |
| `pdf` | PDF operations |
| `playwright-interactive` | Interactive Playwright testing |
| `playwright` | Playwright testing |
| `render-deploy` | Render deployment |
| `screenshot` | Screenshot capture |
| `security-best-practices` | Security best practices |
| `security-ownership-map` | Security ownership mapping |
| `security-threat-model` | Security threat modeling |
| `sentry` | Sentry error tracking |
| `speech` | Speech operations |
| `transcribe` | Transcription |
| `vercel-deploy` | Vercel deployment |
| `winui-app` | WinUI app development |
| `yeet` | Yeet operations |

#### System Skills (5)

| Skill | Description |
|-------|-------------|
| `imagegen` | Image generation |
| `openai-docs` | OpenAI documentation access |
| `plugin-creator` | Plugin creation |
| `skill-creator` | Skill creation |
| `skill-installer` | Skill installation |

---

## Tech Stack Summary

- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS
- **Animation**: Framer Motion
- **Font**: DM Sans (Google Fonts)
- **Language**: TypeScript
- **Package Manager**: npm (main), pnpm (gnhf), bun (portfolio)
- **AI Tools**: OpenCode, GNHF, Ralph Loop, OpenAI Skills/Codex
