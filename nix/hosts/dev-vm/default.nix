# The always-on Lima VM behind `dev` (dot-agents/dev/lima.yaml): the Mac's
# stand-in for sudoAlphaX's Linux laptop. NixOS on nixos-lima's base, rebuilt
# from inside the VM by `dev-rebuild` (the Mac can't build Linux closures).
# Projects get throwaway systemd-nspawn containers (vmdev.sh, container.nix).
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Mac services the containers may call, at 192.168.5.2:<port> (Lima maps it
  # to the Mac's localhost): the GPU stays on the Mac, the containers borrow
  # it over HTTP, like the blog's ollama bridge. Every other Mac port stays
  # blocked. Anything here is usable by every agent in every container.
  macPorts = [
    11434 # Ollama (local LLMs on the Mac's GPU)
    8080 # whisper-server (speech-to-text, from local dictation)
  ];
  # Single services past the LAN/tailnet block, as "address port". Only this
  # pair is reachable; the rest of that host and the tailnet stay blocked.
  remoteServices = [
    "100.64.0.24 8980" # SearXNG (homelab, over the Mac's Tailscale)
    "100.64.0.27 8888" # Jupyter (tailnet)
  ];
  ct = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      { nixpkgs.pkgs = pkgs; }
      ./container.nix
    ];
  };
  vmdev = pkgs.writeShellApplication {
    name = "vmdev";
    runtimeInputs = with pkgs; [
      coreutils
      e2fsprogs # chattr
      jq
      gnugrep
      gnused
      procps # pgrep
      systemd
      util-linux
    ];
    text = builtins.readFile ./vmdev.sh;
  };
in
{
  nixpkgs.config.allowUnfree = true; # claude-code
  networking.hostName = "lima-dev";

  # cache.nixos.org (Fastly) resets about half the connections from this network.
  nix.settings = {
    download-attempts = 30;
    connect-timeout = 10;
    # nixos-lima trusts @wheel, and the Lima user (uid 501, in wheel) is also
    # the containers' uid: a trusted daemon client can add any store path,
    # i.e. root in the VM. Only root is trusted; containers stay plain clients.
    trusted-users = lib.mkForce [ "root" ];
  };
  # Flakes only: no second copy of nixpkgs as a channel (~500 MB), no manuals.
  nix.channel.enable = false;
  documentation.enable = false;
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };
  services.fstrim.enable = true; # gives freed blocks back to the Mac's disk

  # The two Mac folders from dot-agents/dev/lima.yaml. Lima writes them into
  # /etc/fstab at boot, but every switch regenerates fstab and unmounts them,
  # so they are declared here too. Tags are Lima's hash of each path: they only
  # change if the path in lima.yaml does (read them from the cidata `mounts:`).
  fileSystems."/Users/MacbookPro/LocalStorage/Developer" = {
    device = "lima-ea4a7ef152af8f97";
    fsType = "virtiofs";
    options = [
      "rw"
      "nofail"
    ];
  };
  fileSystems."/Users/MacbookPro/.local/share/dev-vm/dots" = {
    device = "lima-3a3a3f0647449684";
    fsType = "virtiofs";
    options = [
      "ro"
      "nofail"
    ];
  };
  zramSwap.enable = true;

  # Nothing left running, nothing left on: vz never returns guest RAM to the
  # Mac. A container stops once its sessions have been empty for 10 minutes
  # (no zellij, agent or shell). A detached zellij session keeps it up while
  # it works (agents left running survive), and for 30 minutes after it goes
  # quiet (under 2% of a core): an idle agent or nvim left behind no longer
  # pins it, and the VM, for days. The VM powers off 5 minutes after its last
  # container, unless a `limactl shell` (a rebuild, a shell) is open; the
  # next `dev` boots it again.
  systemd.services.dev-idle-stop = {
    serviceConfig.Type = "oneshot";
    path = with pkgs; [
      coreutils
      gawk
      procps
      systemd
      vmdev
    ];
    script = ''
      idle() { # MARK BUSY SECONDS: true once not busy for SECONDS
        if (($2)); then rm -f "$1"; return 1; fi
        [[ -e $1 ]] || { touch "$1"; return 1; }
        (($(date +%s) - $(stat -c %Y "$1") >= $3))
      }
      mkdir -p /run/dev-idle.d
      machines=" $(machinectl list --no-legend | cut -d' ' -f1 | tr '\n' ' ') "
      for m in $machines; do
        u=/sys/fs/cgroup/system.slice/$m.service/payload/user.slice
        # Per session: a zellij server without a client is detached; anything
        # else (a client, a shell outside zellij) is someone at a terminal.
        attached=0 detached=0
        for s in "$u"/user-501.slice/session-*.scope; do
          pids=$(paste -sd, "$s/cgroup.procs" 2>/dev/null) || continue
          [[ -n $pids ]] || continue
          args=$(ps -o args= -p "$pids" || true)
          if [[ $args == *"zellij --server"* ]] && ! grep -v -- --server <<<"$args" | grep -q zellij; then
            detached=1
          elif [[ -n $args ]]; then
            attached=1
          fi
        done
        cpu=$(awk '$1 == "usage_usec" {print $2}' "$u/cpu.stat" 2>/dev/null || true)
        cpu=''${cpu:-0}
        prev=$(cat "/run/dev-idle.d/$m.cpu" 2>/dev/null || echo "$cpu")
        echo "$cpu" >"/run/dev-idle.d/$m.cpu"
        # 1.2 s of CPU since the last run (a minute ago): 2% of a core.
        busy=$((attached || (detached && cpu - prev > 1200000)))
        if idle "/run/dev-idle.d/$m" "$busy" $((detached ? 1800 : 600)); then
          vmdev down "$m" && rm -f "/run/dev-idle.d/$m" "/run/dev-idle.d/$m.cpu"
        fi
      done
      for f in /run/dev-idle.d/dev-*; do
        n=''${f##*/}
        [[ -e $f && $machines != *" ''${n%.cpu} "* ]] && rm -f "$f"
      done
      busy=$(machinectl list --no-legend | grep -c . || true)
      ps -eo cgroup=,comm= | awk '$1 ~ /^0::\/user\.slice\/.*session-[0-9]+\.scope/ && $2 != "sshd-session" {b = 1} END {exit !b}' && busy=1
      if idle /run/dev-idle "$busy" 300; then systemctl poweroff; fi
    '';
  };
  systemd.timers.dev-idle-stop = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "1min";
    };
  };

  environment.systemPackages = [
    vmdev
    pkgs.ghostty.terminfo
    pkgs.rsync # `dev` copies your Mac's Claude chats for the project in
  ];
  # The container system; vmdev points the template's init at it on every start.
  environment.etc."dev/ct-system".source = ct.config.system.build.toplevel;

  systemd.tmpfiles.rules = [
    # Template root: everything else comes from the read-only /nix/store bind,
    # so --ephemeral copies a few KB per project. Home is the Mac uid's so
    # nspawn's bind targets under it don't end up root-owned.
    "d /var/lib/machines/dev-template 0755 root root -"
    "d /var/lib/machines/dev-template/etc 0755 root root -"
    "f /var/lib/machines/dev-template/etc/os-release 0644 root root -"
    "d /var/lib/machines/dev-template/var 0755 root root -"
    "d /var/lib/machines/dev-template/nix/store 0755 root root -"
    "d /var/lib/machines/dev-template/sbin 0755 root root -"
    "d /var/lib/machines/dev-template/home/dev 0755 501 100 -"
    "d /var/lib/machines/dev-template/home/dev/.config 0755 501 100 -"
    "d /var/lib/machines/dev-template/home/dev/.local 0755 501 100 -"
    # Tools installed on first use from any container (container.nix); a GC root.
    "d /nix/var/nix/profiles/dev 0755 501 100 -"
    # Shared container state: caches, nvim plugins, dedicated agent logins.
    "d /var/lib/dev/state 0700 501 100 -"
  ]
  ++ map (d: "d /var/lib/dev/state/${d} 0700 501 100 -") [
    "cache"
    "share"
    "state"
    "claude"
    "codex"
    "gh"
    "go"
    "npm"
  ]
  # Claude config, hooks and skills point into the read-only dotfiles (valid
  # inside a container; the logins next to them stay writable). settings.json
  # is a generated copy instead (vmdev).
  ++ map (f: "L+ /var/lib/dev/state/claude/${f} - - - - /home/dev/.dots/dot-config/claude/${f}") [
    "CLAUDE.md"
    "statusline.sh"
    "hooks"
  ]
  ++ [
    "L+ /var/lib/dev/state/claude/skills - - - - /home/dev/.agents/skills"
    # Codex's global instructions: the container notes (container.nix).
    "L+ /var/lib/dev/state/codex/AGENTS.md - - - - /etc/claude-code/CLAUDE.md"
  ];

  # Containers share the VM's network (so Lima forwards their dev servers to
  # the Mac's localhost) and run as uid 501, like the Lima user, which needs
  # no LAN either. The blog's ufw rules, per uid: the internet yes; the LAN,
  # link-local and the Mac (192.168.5.2 under Lima's user-mode network) no,
  # except DNS, which Lima serves from .2/.3, the macPorts and remoteServices. Inbound from the Mac (Lima's
  # forwards and ssh) is unaffected.
  networking.useNetworkd = true;
  networking.nftables = {
    enable = true;
    tables.dev-egress = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;
          # uid 501: the containers; gid nixbld: the daemon's build users, whose
          # fixed-output builds (any container can request one) have network.
          meta skuid != 501 meta skgid != ${toString config.ids.gids.nixbld} accept
          ct state established,related accept
          ip daddr { 192.168.5.2, 192.168.5.3 } meta l4proto { tcp, udp } th dport 53 accept
          ip daddr 192.168.5.2 tcp dport { ${lib.concatMapStringsSep ", " toString macPorts} } accept
          ${lib.concatMapStringsSep "\n" (
            r:
            let
              a = lib.splitString " " r;
            in
            "ip daddr ${lib.elemAt a 0} tcp dport ${lib.elemAt a 1} accept"
          ) remoteServices}
          ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 100.64.0.0/10 } reject
          ip6 daddr { fc00::/7, fe80::/10 } reject
        }
      '';
    };
  };
}
