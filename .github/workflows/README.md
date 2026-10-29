# Workflows

Modeled on nixpkgs' `.github/workflows`: one orchestrator calls reusable
workflows, and a single gate job is the required status check.

```text
ci.yml  (pull_request → main, push → main, workflow_dispatch)
├─ prepare      which paths changed
├─ lint.yml     pre-commit · nixfmt · zizmor · gitleaks        always
├─ build.yml    eval (all systems) → matrix, one job per system  nix changed
│    ├─ aarch64-darwin  macos-15          darwinConfigurations + packages
│    └─ aarch64-linux   ubuntu-24.04-arm  nixosConfigurations.dev-vm
├─ switch.yml   MacbookPro switched on a fresh Mac              nix changed, main only
└─ ci ok        fails if any job above failed or was cancelled
```

- **Required check:** only `ci ok`. Path-skipped jobs count as passed, so
  branch protection never waits on a job that didn't run. Don't rename it.
- **What gets built** is the flake's `checks` output (`nix/flake.nix`).
  `nix flake check` builds the current system's checks, so each matrix row
  only picks a runner. Locally, `nix flake check ./nix` builds the same thing.
- **Adding a host:** a darwin host is picked up automatically from
  `darwinConfigurations`. A NixOS host needs a `checks.<system>.<name>` entry,
  and a matrix row in `build.yml` if it's a new system.
- **Permissions** are `{}` at the top of every workflow and granted per job.
  Every action is pinned to a commit SHA.
- **Nix setup** is `.github/actions/setup-nix`: upstream Nix plus the store
  cached in the GitHub Actions cache. Only `main` saves caches.
- **Concurrency:** new pushes to a PR cancel its older run; runs on `main`
  never cancel each other.
- `update-flake-lock.yml` opens a weekly PR bumping every flake input.
