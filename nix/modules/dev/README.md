# dev: one microVM per project

`cd project && dev` boots a NixOS microVM for that project, if it isn't running yet, and attaches zellij inside it. Every project boots **the same guest closure**. Only devctl's arguments differ per project, so a new project never triggers a Linux build.

```text
macOS (nix-darwin)
├── dev (zsh, .zshalias)    → finds the project (git root or $PWD), calls devctl
├── devctl (devctl.sh)      → per-project vfkit VM: lifecycle, attach, status
├── devvm-pf (launchd)      → pf anchor com.apple/250.devvm: guests get the internet only
├── nix.linux-builder       → ephemeral, builds the guest on darwin-rebuild
└── vfkit, one per project
    └── NixOS aarch64 guest (guest.nix + _guest-common.nix)
        ├── /nix/store      erofs image (read-only) + overlay on /persist/nix-rw
        ├── /workspace      the project, virtiofs, read-write
        ├── ~/.dots         fresh per-boot copy of the git-tracked dotfiles, virtiofs, mounted ro
        ├── /mnt/exchange   per-project exchange dir, virtiofs
        ├── /persist        per-project ext4 volume (sparse 24G file), formatted on first boot
        ├── sshd on vsock   port 22 only; devctl connects through vfkit's unix socket
        └── nftables        second layer; the Mac-side pf rules are the wall
```

Files: `guest.nix` (the guest, `nixosConfigurations.dev-guest`), `_guest-common.nix` (user, tools, agents), `host-darwin.nix` (builder, pf daemon, devctl, boot artefacts in `/etc/devvm/guest.env`), `devctl.sh`, `devvm_ssh.pub` (the guests' one authorized key).

devctl doesn't use microvm.nix's vfkit runner, which only supports NAT, has no vsock, can't mark shares read-only and bakes per-project paths into the runner. It reproduces the runner's kernel, initrd, cmdline and store-disk arguments (`lib/runners/vfkit.nix`) and adds vsock, the per-project shares and volume, a REST socket and a serial log.

## Commands

| | |
|---|---|
| `dev` | boot if needed, `zellij attach -c <dir>@<branch>`. No sign-in prompts: run `claude`, `opencode`, `gh auth login` etc. inside when you need them; logins persist per project |
| `dev start` / `dev stop` | boot without attaching / ACPI stop (REST `Stop`), `HardStop` after 60 s |
| `dev status` | state, pid, guest IP, forwards, state dir size, whether it runs an older guest |
| `dev forward 3000` / `dev forward 8080:3000` | guest port 3000 on `http://localhost:3000` (or `:8080`), in the background; `dev forward` lists, `dev forward -d [PORT]` stops. Works for servers bound to the guest's localhost too |
| `dev destroy` | stop and delete the project's state dir (asks first) |
| `dev ls` | every project with state, running or not |
| `dev logs` | follow the serial console |

Also:

- **Idle stop:** a guest powers itself off after 10 min with no SSH session (`dev`, `dev forward`), or 30 min when only an idle, detached zellij is left. `touch /persist/no-idle-stop` inside turns this off.
- **Updates:** after a darwin-rebuild, `dev` offers to restart a VM still running the old guest.
- **Claude settings:** `~/.claude/settings.json` in the guest is your `dot-config/claude/settings.json` minus `ask` rules, rewritten at every boot, so an edit needs `dev stop && dev`, not a rebuild. `/workspace` is pre-trusted once you've signed in. Only `sandbox off` and `bypassPermissions` are baked in (managed settings).
- **Git identity:** your Mac's `user.name` and `user.email` are written into the guest's `~/.gitconfig` at each `dev`.
- **Nix store:** what a project builds or fetches stays across boots: the store overlay and the nix database both live on `/persist`. The uv cache is pruned weekly.
| `devctl sessions` / `devctl attach ID SESSION` | used by the `zellij` wrapper (`zellij ls`, `zellij attach`) |
| `devctl run ID CMD` | run a command in a running guest, non-interactively (used by `skills-audit`) |

## State

Id: `dev-<basename, sanitised, max 40>-<first 8 hex of sha256(canonical path)>`, so no lookup is needed.

```text
~/.local/state/devvm/
├── ssh/id_ed25519{,.pub}   devctl's key; .pub is committed as devvm_ssh.pub
└── <id>/
    ├── persist.img         /persist (sparse)
    ├── src                 canonical project path
    ├── pid, rest.sock, vsock-ssh.sock, console.log, vfkit.log
    ├── known_hosts         the guest's host key (kept on /persist/ssh)
    ├── git.fp              fingerprint of .git/config + hooks (devctl warns on change)
    ├── lock/               mkdir lock: one boot/stop at a time
    ├── exchange/           /mnt/exchange
    └── dots/               this boot's dotfiles copy (APFS clone)
~/.local/share/devvm/dots   the export: git-tracked files of dot-config/{zsh,claude,nvim,starship,lazygit,opencode} and dot-agents
```

Only the git-tracked files are exported, never `nix/`, so `secrets.nix` and its Keychain names never leave the Mac. `.zsh_history` is never exported either, because it isn't tracked.

## Security model

- **Nothing of the Mac's reaches a guest except the project.** No Mac `/nix/store` (the guest boots an erofs image, and the Mac's case-insensitive store would mangle Linux paths anyway), no home, `~/.ssh`, `~/.gnupg`, Keychain, SSH or GPG agent, Docker socket or credential file. devctl's ssh runs with `-F /dev/null`, `IdentityAgent=none` and no forwarding.
- **No way up inside.** `dev` has no wheel, sudo is disabled, root and dev have locked passwords, and sshd allows `dev` only, by key, on vsock only. `AllowTcpForwarding local` lets the Mac reach guest ports, while the guest gets nothing on the Mac.
- **Network: fail closed.** devctl won't boot unless `/var/run/devvm-pf.status` is root-owned, under 90 s old and says `loaded`. The `devvm-pf` daemon (`org.nixos.devvm-pf`) re-applies the anchor every 30 s and turns pf back on if something turned it off, keeps its own pf enable token, and checks that the main ruleset still has the `com.apple/*` anchor point.
  - pf rules: the guest subnet (vmnet, `192.168.64.0/24` by default, read from `com.apple.vmnet.plist`) may reach the gateway on DNS and DHCP only. It is blocked from RFC1918, `100.64.0.0/10` (Tailscale), `169.254.0.0/16`, multicast and the Mac's own addresses; IPv6 ULA and link-local are blocked on the vmnet bridges.
  - The guest's nftables rules do the same again, and also drop inbound traffic from other guests.
  - DNS: guests ignore the gateway (vmnet answers nothing there on this Mac) and use Cloudflare and Quad9 directly, with DNS-over-TLS when available, so the Mac's DNS, Tailscale MagicDNS and LAN names stay out of the guest.
  - Apple doesn't treat pf as an API, and macOS updates can reset it: re-run the checklist after every macOS update.
- **Mac-side git.** A guest can write `.git/config` and hooks in its project. Inside guest projects the `.zshalias` git guard forces `core.fsmonitor=false` and `core.hooksPath=/dev/null` through `GIT_CONFIG_COUNT`, which takes precedence over `.git/config` and covers lazygit too. It doesn't cover filters, `core.pager`, `core.sshCommand` or aliases. devctl warns after each session when `.git/config` or the hooks changed.

## Security checklist (run inside a guest, after a darwin-rebuild or macOS update)

```sh
# Mac, LAN, Tailscale, other guests, link-local: all refused or time out
curl -m 3 http://192.168.64.1:22 ; curl -m 3 http://<mac-lan-ip>:<any-open-port>
curl -m 3 http://192.168.1.1 ; curl -m 3 http://100.100.100.100 ; curl -m 3 http://169.254.169.254
curl -m 3 http://<other-guest-ip>:<port>   # from `dev status` in the other project
ping -6 -c1 -w3 ff02::1%eth0               # IPv6 is off: should fail
curl -sI https://cache.nixos.org | head -1 # internet works
sudo -n true                               # fails: no sudo
touch /workspace/.probe                    # then on the Mac: ls -l .probe → owned by you; rm it
echo hi > /persist/cache/probe; echo hi > ~/probe   # dev stop && dev: the first survives, the second is gone
```

On the Mac: after `dev destroy`, `ls ~/.local/state/devvm/<id>` fails and `pgrep -fl vfkit` doesn't list that project. Fail closed: `sudo launchctl bootout system/org.nixos.devvm-pf; sudo pfctl -d; sudo rm /var/run/devvm-pf.status`. `dev` in a stopped project must now refuse to boot. Restore with `sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.devvm-pf.plist`, or `darwin-rebuild switch`. While the daemon runs, a `pfctl -d` alone is undone within 30 s; devctl can't see pf itself without root, so a VM booted in that window has no Mac-side wall until then, only its own nftables.

## Known issue: Tailscale exit node

With a Tailscale exit node on and "Allow local network access" off (`ExitNodeAllowLANAccess: false`), the Mac can't reach the vmnet bridge, so guests have no network at all (SSH still works, it's vsock). Turn the exit node off, or `tailscale set --exit-node-allow-lan-access=true` (untested with an exit node on).

Verified on 2026-11-28: with the guest's nftables removed, pf alone refused the Mac (gateway, LAN and Tailscale IPs), the router, `100.100.100.100`, `169.254.169.254` and another guest, while HTTPS and DNS to the internet worked.
