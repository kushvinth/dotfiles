---
name: kushvinth-design-rules
description: Kushvinth's design rules and aesthetic for building/designing web pages, landing pages, portfolios, and UI. Use when the user says "/kush", asks to build something "in Kushvinth's style", designs or codes a landing page, portfolio site, blog, or UI component, picks fonts/colors/motion, or needs the K Studio / kushvinth.com design language. Also holds the inspiration repo & skill index for the ai-dot project.
---

# Kushvinth Design Rules

Design language and stack for kushvinth's projects (K Studio, kushvinth.com, portfolio). Ground every design decision in these rules, then borrow freely from the inspiration sources below.

## Core identity

- **Dark-first, clean, motion-forward.** Dark backgrounds as the default, generous whitespace, sharp or minimal borders, one crisp accent color used sparingly.
- **Typography**: **DM Sans** (Google Fonts) as the primary typeface.
- **Motion**: **Framer Motion** for entrance animations, hover states, and scroll-triggered reveals. Motion is tasteful and deliberate — never decorative noise.
- **Style**: modern, minimal, "AI consultancy / indie builder" feel — not corporate, not playful. Think polished dev portfolio meets premium AI product.

## Non-negotiables (do not skip)

- TypeScript everywhere.
- Next.js 14 (App Router) + Tailwind CSS as the base stack unless told otherwise.
- Follow an existing page's patterns before inventing new ones: reuse its components, spacing scale, and color usage.
- Mobile-first responsive. Test at 375px before celebrating.

## Inspiration sources (check before designing)

| Source | Why |
|--------|-----|
| [originkit.dev/components](https://www.originkit.dev/components/) | Component ideas; the [tornado](https://www.originkit.dev/components/tornado) is the go-to reference |
| [ui.aceternity.com](https://ui.aceternity.com/components) | Animated UI primitives |
| [motionsites.ai](https://motionsites.ai/) | Motion-heavy site references |
| [styles.refero.design](https://styles.refero.design/) | Visual style / color direction |

Pull visual ideas from these, then execute in this project's stack. When in doubt, ship the simpler version of the reference.

## Reference projects (what to imitate)

| Project | Role |
|---------|------|
| [kushvinth.com](https://kushvinth.com) | Author's portfolio — the target aesthetic for personal work |
| [nexxeln/nexxel.dev](https://github.com/nexxeln/nexxel.dev) | Portfolio/blog template (Next.js, Tailwind, TS, MDX) — base for blog/portfolio structure |
| [kushvinth/portfolio](https://kushvinth.com) | Portfolio with blog posts + SEO (Next.js, MDX, Bun) |
| [tanishkadeep/landing-page](https://github.com/tanishkadeep/landing-page) | K Studio landing page — the main project (Next.js, Tailwind, TS, Framer Motion) |

## Repo index

Reference indexes for the ai-dot project (repos and skills, forked or embedded elsewhere).

### Forks / embeds

| Repo | Location | Stack | Description |
|------|----------|-------|-------------|
| [nexxeln/nexxel.dev](https://github.com/nexxeln/nexxel.dev) | `startinspo/` | Next.js, Tailwind, TypeScript, MDX, Vercel | Personal site & blog template |
| [kunchenguid/gnhf](https://github.com/kunchenguid/gnhf) | `docs/gnhf/` | Node.js, TypeScript, ESM | Overnight agent orchestrator |
| [tanishkadeep/landing-page](https://github.com/tanishkadeep/landing-page) | `docs/lol-git-backup/` | Next.js, Tailwind, TypeScript | Original landing page backup |
| [kushvinth/portfolio](https://kushvinth.com) | `docs/portfolio/` | Next.js, MDX, Bun | Portfolio with blog + SEO |
| [openai/skills](https://github.com/openai/skills) | `skills/` | Markdown, Shell | Codex skill catalog (pinned `49f948f`) |

### Referenced by gnhf

| Repo | Description |
|------|-------------|
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | Autoresearch-style orchestration |
| [ghuntley.com/ralph](https://ghuntley.com/ralph/) | Overnight agent runner concept |
| [openclaw/acpx](https://github.com/openclaw/acpx) | ACP runtime + agent registry |
| [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) | AI review/test/lint gate for pushes |
| [github/copilot-cli](https://github.com/github/copilot-cli) | Copilot CLI (supported agent) |

## Tech stack summary

- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS
- **Animation**: Framer Motion
- **Font**: DM Sans (Google Fonts)
- **Language**: TypeScript
- **Package Manager**: npm (main), pnpm (gnhf), bun (portfolio)
- **AI Tools**: OpenCode, GNHF, Ralph Loop, OpenAI Skills/Codex

## Notes

- Full design source-of-truth lives in the external repos above; this skill distills them so agents can design without fetching.
- `dot-agents/inspo.md` in the dotfiles repo mirrors the inspiration-source links.
