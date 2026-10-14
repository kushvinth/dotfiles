# The system every `dev` container boots (sudoAlphaX's /var/lib/machines/dev-<uid>
# template, as a NixOS closure). Built inside the dev-vm config, so its store
# paths are shared with the VM and bound read-only into each container.
{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  locate =
    inputs.nix-index-database.packages.${pkgs.stdenv.hostPlatform.system}.nix-index-with-small-db;
  # On-demand tools, shared by every container; lives in the VM, a GC root.
  tools = "/nix/var/nix/profiles/dev/tools";
in
{
  boot.isContainer = true;
  system.stateVersion = "26.05";

  # The Mac user's uid, so files written to the project keep their owner
  # (virtiofs has no idmap, see docs/hardening.md). Not a "normal" user: NixOS
  # wants uid >= 1000 for those.
  users.users.dev = {
    uid = 501;
    group = "users";
    home = "/home/dev";
    createHome = true;
    shell = pkgs.zsh;
    # Keeps /run/user/501 (zellij's sockets) after you leave the last shell, so
    # sessions with agents still running can be reattached.
    linger = true;
  };
  environment.systemPackages = import ./packages.nix pkgs ++ [
    pkgs.ghostty.terminfo
    locate # nix-locate: which package has a command
  ];
  # Last in PATH, after /run/current-system/sw (which NixOS adds with
  # mkAfter): any container can add tools here, so they can add commands but
  # never shadow the base ones (git, claude, ls).
  environment.profiles = lib.mkOrder 2000 [ tools ];

  # Your zsh comes from the read-only dotfiles bind (vmdev); history and
  # caches go to the shared state dir instead.
  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false; # oh-my-zsh runs compinit
    # Install on first use: a missing command offers its nixpkgs package (same
    # nixpkgs as the Mac) and installs it into the profile every container
    # shares. Agents (no tty) get the command to run instead of a prompt.
    # In zshenv because your .zshenv sets NOSYSZSHRC, which skips /etc/zshrc.
    shellInit = ''
      # A caller that reset PATH (and inherited __NIXOS_SET_ENVIRONMENT_DONE,
      # so set-environment is skipped) still gets the base tools, appended.
      [[ :$PATH: == *:/run/current-system/sw/bin:* ]] || PATH=$PATH:/run/current-system/sw/bin
      command_not_found_handler() {
        # Builtins only (no head, no PATH lookups): with a PATH that lacks
        # coreutils, `| head` re-entered this handler and fork-bombed the VM.
        [[ -n $_dev_cnf ]] && { print -u2 "zsh: command not found: $1"; return 127; }
        local _dev_cnf=1
        local p=''${''${(f)"$(${locate}/bin/nix-locate --minimal --whole-name --at-root "/bin/$1" 2>/dev/null)"}[1]}
        p=''${p%.out}
        if [[ -z $p ]]; then
          print -u2 "zsh: command not found: $1"
        elif [[ -t 0 && -t 2 ]] && read -q "?$1 is in nixpkgs#$p. Install it for every dev container? [y/N] " </dev/tty 2>/dev/tty; then
          print -u2
          NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure --profile ${tools} "nixpkgs#$p" && rehash && "$@"
          return
        else
          [[ -t 0 && -t 2 ]] && print -u2
          print -u2 "$1: not installed. It is nixpkgs#$p; install for every dev container with: NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure --profile ${tools} nixpkgs#$p"
        fi
        return 127
      }
    '';
  };
  environment.variables = {
    ZDOTDIR = "/home/dev/.config/zsh";
    HISTFILE = "/home/dev/.cache/zsh_history";
    EDITOR = "nvim";
    # Keeps ~/.claude.json (account, onboarding, trusted folders) in the
    # persistent ~/.claude, so a fresh container doesn't log in again.
    CLAUDE_CONFIG_DIR = "/home/dev/.claude";
    NIX_REMOTE = "daemon";
    OLLAMA_HOST = "http://192.168.5.2:11434"; # the Mac's Ollama (dev-vm macPorts)
    SEARXNG_URL = "http://100.64.0.24:8980"; # homelab SearXNG (dev-vm remoteServices)
    # A directory, not file binds: `dev` re-exports the dotfiles every run,
    # and a bind-mounted file would keep pointing at the replaced copy.
    ZELLIJ_CONFIG_DIR = "/home/dev/.agents/dev/zellij";
  };
  systemd.tmpfiles.rules = [ "L+ /home/dev/.oh-my-zsh - - - - ${pkgs.oh-my-zsh}/share/oh-my-zsh" ];

  # The container is the sandbox, so Claude runs without asking: its own
  # sandbox (bubblewrap) off, every session in bypassPermissions, no warning
  # dialog. vmdev also drops your `ask` rules from the container's copy of
  # settings.json and trusts each project folder. Deny rules still apply.
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    sandbox.enabled = false;
    permissions.defaultMode = "bypassPermissions";
    skipDangerousModePermissionPrompt = true;
  };
  # git pushes over https with the containers' own gh login (signed in on the first `dev`), not the Mac's.
  programs.git = {
    enable = true;
    lfs.enable = true; # as on the Mac: LFS repos check out real files, not pointers
    # The Mac's defaults (nix/modules/home/git.nix); name and email come from `dev`.
    config.init.defaultBranch = "main";
    config.pull.rebase = false;
    config.credential = {
      "https://github.com".helper = "!gh auth git-credential";
      "https://gist.github.com".helper = "!gh auth git-credential";
    };
  };

  # The VM's network, shared (vmdev starts nspawn without --network-veth): a dev
  # server on any port shows up on the Mac at localhost:PORT, forwarded by
  # Lima. The VM's nftables keep the containers off the LAN and the Mac.
  networking = {
    useDHCP = false;
    useHostResolvConf = true;
    firewall.enable = false;
  };

  # Generic Linux binaries (uv-managed Pythons, manylinux wheels, npm native
  # modules, language servers fetched by tools) expect /lib/ld-linux; nix-ld
  # provides it, so they run here as on any distro.
  programs.nix-ld.enable = true;

  # Tells agents where they are: Claude reads this as system-wide memory, Codex
  # through ~/.codex/AGENTS.md (dev-vm/default.nix). Without it they follow
  # the Mac-only parts of ~/.agents/AGENTS.md.
  environment.etc."claude-code/CLAUDE.md".source = ./AGENTS.md;

  services.journald.settings.Journal = {
    Storage = "volatile";
    RuntimeMaxUse = "16M";
  };
  # nix here is only a client of the VM's daemon (vmdev binds its socket), as
  # an untrusted user: it can fetch and build into the shared store, nothing
  # more. `nixpkgs` is the VM's own pin, i.e. the Mac's flake.lock.
  nix.enable = false; # no daemon in the container
  environment.etc."nix/nix.conf".text = "experimental-features = nix-command flakes\n";
  environment.etc."nix/registry.json".text = builtins.toJSON {
    version = 2;
    flakes = [
      {
        from = {
          type = "indirect";
          id = "nixpkgs";
        };
        to = {
          type = "path";
          path = "${inputs.nixpkgs}";
        };
      }
    ];
  };
}
