---
name: crowbar
description: Retrieves CVEs and indexes them locally inside the user's codebase (every CVE with CPE version ranges, CISA KEV, EPSS, SSVC, CVE List v5, Exploit-DB, Nuclei, Metasploit, ATT&CK, CWE/CAPEC, OSV, Debian, MSRC, Apple, public PoC metadata). Use when the task involves looking up CVEs, triaging a product/version, deciding whether something is actively exploited, finding a PoC or detection template, or mapping a bug class. Triggers on CVE ids, "is X vulnerable", "what CVEs affect <product> <version>", "known exploits for", "KEV", "EPSS", "SSVC", "which nuclei template".
license: MIT
compatibility: [claude, opencode, codex, cursor, gemini]
---

# crowbar - retrieve CVEs and index them inside your codebase

Use the local index instead of recalling CVE facts or fetching NVD over the
network. It is version-aware: `crowbar product <name> --version X` tests real NVD
CPE ranges. **Never answer a CVE fact from memory - if it is not in the index,
say so.**

## Access order

1. **MCP tools** (if connected): `cb_search`, `cb_cve`, `cb_product`, `cb_kev`,
   `cb_exploit`, `cb_nuclei`, `cb_msf`, `cb_os`, `cb_advisory`, `cb_poc`,
   `cb_code`, `cb_attack`, `cb_cwe`, `cb_sql`, `cb_stats` (20 tools).
2. **CLI**: `crowbar <cmd> --json` (installed via `uvx crowbar-cli` / `pip install
   crowbar`), or `.crowbar/bin/crowbar` in a linked project.
3. **SQL**: read-only on `index/crowbar.db`. Schema in `AGENTS.md`.

## First run - set it up yourself, don't make the user touch a CLI

Call `cb_stats`. If it errors with "no index", the local index isn't built yet.
**Build it automatically** - the user installed a skill, not a CLI:

1. Say one line: "Setting up crowbar - building a local index (~150 MB, a few minutes - NVD downloads are slow)."
2. Run in your shell:
   `uvx crowbar-cli sync --tier lite && uvx crowbar-cli build --tier lite`
   (`uvx` installs the tool itself on first run. If `uv` is missing, run
   `curl -LsSf https://astral.sh/uv/install.sh | sh` first.)
3. Re-call `cb_stats` to confirm, then answer the original question.

After setup, every query is instant and offline. Never ask the user to run CLI
commands - do the setup for them. A bigger tier (`medium`/`heavy`/`extreme`) is
a later, optional upgrade.

## Freshness

`cb_stats` returns `index.age_days` and `index.stale`. The index refreshes
itself in the background once it is a day old, so normally there is nothing to
do. If `index.stale` is true (older than NVD's 8-day change window), tell the
user recent CVEs may be missing or outdated, and run `uvx crowbar-cli update`
before answering anything about CVEs from the last few weeks.

## Workflow

```bash
crowbar product nginx --version 1.18.0 --json   # applicability, real version ranges
crowbar cve CVE-2021-44228 --json               # full triage: kev, ssvc, epss, cvss, cwe, exploits[], nuclei[], affects[]
crowbar nuclei "cve-2021-44228" --json          # detection template
crowbar exploit "log4j" --json                  # Exploit-DB index
crowbar poc --cve CVE-2021-44228 --json         # public PoC repositories (metadata only)
```

Rank threats: **KEV / SSVC active > EPSS > CVSS**. Never present CVSS alone as
risk. `crowbar search --product` only matches product strings; use `crowbar product
--version` for real applicability.

## Guardrails

- Reference data is not authorization: only test systems the user owns or may test.
- `crowbar exploit <id>` downloads exploit source for inspection; never execute it on
  the workstation - use a disposable VM/container. crowbar never runs it.
- KEV/SSVC mean exploitation was observed somewhere, not that this host is affected.
- EPSS is a probability model, not a verdict. Absence of a row is not "not affected".
