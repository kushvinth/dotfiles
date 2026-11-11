# The always-on Lima VM behind `dev` (dot-agents/dev/lima.yaml): the Mac's
# stand-in for sudoAlphaX's Linux laptop. NixOS on nixos-lima's base, rebuilt
# from inside the VM by `dev-rebuild`.
# Projects get throwaway systemd-nspawn containers (vmdev.sh, container.nix).
{
  inputs,
  dotfilesLib,
  ...
}:
{
  configurations.nixos.dev-vm.module =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      macPorts = [
        11434 # Ollama
        10100 # Magnitude
      ];
      remoteServices = [
        "100.64.0.24 8980" # SearXNG
        "100.64.0.27 8888" # Jupyter
      ];
      ct = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs dotfilesLib; };
        modules = [
          { nixpkgs.pkgs = pkgs; }
          ./_container.nix
        ];
      };
      vmdev = pkgs.writeShellApplication {
        name = "vmdev";
        runtimeInputs = with pkgs; [
          coreutils
          e2fsprogs
          jq
          gnugrep
          gnused
          procps
          systemd
          util-linux
        ];
        text = builtins.readFile ./vmdev.sh;
      };
    in
    {
      imports = [
        "${inputs.nixos-lima}/lima.nix"
      ];

      nixpkgs.config.allowUnfree = true;
      networking.hostName = "lima-dev";

      nix.settings = {
        download-attempts = 30;
        connect-timeout = 10;
        trusted-users = lib.mkForce [ "root" ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      nix.channel.enable = false;
      documentation.enable = false;
      nix.gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };
      services.fstrim.enable = true;

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
          idle() {
            if (($2)); then rm -f "$1"; return 1; fi
            [[ -e $1 ]] || { touch "$1"; return 1; }
            (($(date +%s) - $(stat -c %Y "$1") >= $3))
          }
          mkdir -p /run/dev-idle.d
          machines=" $(machinectl list --no-legend | cut -d' ' -f1 | tr '\n' ' ') "
          for m in $machines; do
            u=/sys/fs/cgroup/system.slice/$m.service/payload/user.slice
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

      systemd.services.dev-cache-prune = {
        serviceConfig = {
          Type = "oneshot";
          User = "501";
          Environment = "UV_CACHE_DIR=/var/lib/dev/state/cache/uv";
          ExecStart = "${lib.getExe pkgs.uv} cache prune";
        };
      };
      systemd.timers.dev-cache-prune = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
      };

      systemd.sockets.ollama-proxy = {
        wantedBy = [ "sockets.target" ];
        listenStreams = [ "127.0.0.1:11434" ];
      };
      systemd.services.ollama-proxy.serviceConfig.ExecStart =
        "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 192.168.5.2:11434";

      systemd.sockets.magnitude-proxy = {
        wantedBy = [ "sockets.target" ];
        listenStreams = [ "127.0.0.1:10100" ];
      };
      systemd.services.magnitude-proxy.serviceConfig.ExecStart =
        "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 192.168.5.2:10100";

      environment.systemPackages = [
        vmdev
        pkgs.ghostty.terminfo
        pkgs.rsync
      ];
      environment.etc."dev/ct-system".source = ct.config.system.build.toplevel;

      systemd.tmpfiles.rules = [
        "d /var/lib/machines/dev-template 0755 root root -"
        "d /var/lib/machines/dev-template/etc 0755 root root -"
        "f /var/lib/machines/dev-template/etc/os-release 0644 root root -"
        "d /var/lib/machines/dev-template/var 0755 root root -"
        "d /var/lib/machines/dev-template/nix/store 0755 root root -"
        "d /var/lib/machines/dev-template/sbin 0755 root root -"
        "d /var/lib/machines/dev-template/home/dev 0755 501 100 -"
        "d /var/lib/machines/dev-template/home/dev/.config 0755 501 100 -"
        "d /var/lib/machines/dev-template/home/dev/.local 0755 501 100 -"
        "d /nix/var/nix/profiles/dev 0755 501 100 -"
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
      ++ map (f: "L+ /var/lib/dev/state/claude/${f} - - - - /home/dev/.dots/dot-config/claude/${f}") [
        "CLAUDE.md"
        "statusline.sh"
        "hooks"
      ]
      ++ [
        "L+ /var/lib/dev/state/claude/skills - - - - /home/dev/.agents/skills"
        "L+ /var/lib/dev/state/codex/AGENTS.md - - - - /etc/claude-code/CLAUDE.md"
      ];

      networking.useNetworkd = true;
      networking.nftables = {
        enable = true;
        tables.dev-egress = {
          family = "inet";
          content = ''
            chain output {
              type filter hook output priority 0; policy accept;
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
    };
}
