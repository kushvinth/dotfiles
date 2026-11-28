# The `dev` microVM guest (nixosConfigurations.dev-guest), one closure for
# every project. Built with microvm.nix (kernel, initrd, erofs store image),
# launched by devctl (devctl.sh) with vfkit on the Mac. Everything per-project
# (shares, volume, MAC, sockets) is a devctl argument, never part of this
# closure, so a new project never triggers a Linux build. See README.md.
{
  inputs,
  config,
  dotfilesLib,
  ...
}:
{
  configurations.nixos.dev-guest.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      home = "/home/dev";
      # /persist/<dir> → ~/<path>, owned by dev. Everything else is RAM and
      # gone at the next boot.
      persistBinds = {
        cache = ".cache";
        go = "go";
        cargo = ".cargo";
        # Like the old containers: all of ~/.local/share (nvim plugins, pnpm
        # store, ...) and the npm cache.
        share = ".local/share";
        npm = ".npm";
        claude = ".claude";
        codex = ".codex";
        gh = ".config/gh";
        state = ".local/state";
        history = ".history";
      };
      # Read-only config from the per-launch dotfiles copy (devctl).
      dotsBinds = {
        "dot-config/zsh" = ".config/zsh";
        "dot-config/nvim" = ".config/nvim";
        "dot-config/starship" = ".config/starship";
        "dot-config/lazygit" = ".config/lazygit";
        "dot-agents" = ".agents";
      };
      virtiofs = tag: extra: {
        device = tag;
        fsType = "virtiofs";
        options = [
          "nofail"
          "x-systemd.after=systemd-modules-load.service"
        ]
        ++ extra;
      };
      # Must match devctl's --timesync vsockPort.
      timesyncPort = 1024;
    in
    {
      imports = [
        inputs.microvm.nixosModules.microvm
        ./_guest-common.nix
      ];
      _module.args.dotfilesLib = dotfilesLib;

      # Same name in every guest; the project is visible from /workspace.
      networking.hostName = "dev";

      microvm = {
        # Only for option compatibility: devctl reproduces lib/runners/vfkit.nix
        # (kernel, initrd, cmdline, store disk) and adds vsock, per-project
        # shares and volume, the REST socket and a serial log.
        hypervisor = "vfkit";
        vcpu = 4;
        mem = 4096;
        storeOnDisk = true;
        storeDiskType = "erofs";
        writableStoreOverlay = "/persist/nix-rw";
        # Per-project, so declared by devctl and fileSystems below instead.
        shares = [ ];
        volumes = [ ];
        interfaces = [ ];
      };

      boot.kernelModules = [ "vmw_vsock_virtio_transport" ];
      # sshd listens on vsock only (below); systemd's own vsock sshd generator
      # would add a second socket.
      boot.kernelParams = [ "systemd.ssh_auto=no" ];

      # /persist: the per-project virtio-blk volume, the second disk after the
      # store image. devctl hands over a blank sparse file on first use; it is
      # formatted on first boot. Needed in the initrd for the store overlay.
      fileSystems = lib.mkMerge [
        {
          "/persist" = {
            device = "/dev/vdb";
            fsType = "ext4";
            autoFormat = true;
            neededForBoot = true;
          };
          "/workspace" = virtiofs "workspace" [ ];
          # vfkit can't mark a share read-only: ro here, and devctl gives each
          # launch a fresh copy, so a guest can only spoil its own.
          "${home}/.dots" = virtiofs "dots" [ "ro" ];
          "/mnt/exchange" = virtiofs "exchange" [ ];
        }
        (lib.mapAttrs' (
          dir: path:
          lib.nameValuePair "${home}/${path}" {
            device = "/persist/${dir}";
            fsType = "none";
            options = [
              "bind"
              "x-systemd.requires=dev-persist-dirs.service"
              "x-systemd.after=dev-persist-dirs.service"
            ];
          }
        ) persistBinds)
        (lib.mapAttrs' (
          src: path:
          lib.nameValuePair "${home}/${path}" {
            device = "${home}/.dots/${src}";
            fsType = "none";
            options = [
              "bind"
              "ro"
              "nofail"
            ];
          }
        ) dotsBinds)
      ];

      systemd.services.dev-persist-dirs = {
        description = "Create the per-project persistent directories";
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/persist";
        };
        before = [ "local-fs.target" ];
        wantedBy = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for d in ${lib.concatStringsSep " " (lib.attrNames persistBinds)}; do
            install -d -o 501 -g 100 -m 0700 "/persist/$d"
          done
          install -d -o root -g root -m 0700 /persist/ssh
          install -d -o root -g root -m 0755 /persist/nix-build
        '';
        path = [ pkgs.coreutils ];
      };

      # The nix database on /persist too, so what a project builds or fetches
      # (into the store overlay) stays valid across boots: otherwise the RAM
      # root forgets it and nix fetches it all again. Replaces microvm.nix's
      # load-db in postBootCommands, which would run before /persist is bound.
      boot.postBootCommands = lib.mkForce "";
      systemd.services.dev-nix-db = {
        description = "Persistent nix database on /persist";
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/persist /nix/store";
        };
        after = [
          "local-fs.target"
          "dev-persist-dirs.service"
        ];
        requires = [ "dev-persist-dirs.service" ];
        # Before tmpfiles, so its /nix/var/nix links (gcroots) land on the
        # bind. Wanted, not required, by nix-daemon: if this fails, nix still
        # works, with a database that only lasts until the next boot.
        before = [
          "systemd-tmpfiles-setup.service"
          "sysinit.target"
          "nix-daemon.socket"
          "nix-daemon.service"
          "shutdown.target"
        ];
        wantedBy = [
          "sysinit.target"
          "nix-daemon.socket"
          "nix-daemon.service"
        ];
        conflicts = [ "shutdown.target" ];
        path = [
          config.nix.package
          pkgs.coreutils
          pkgs.util-linux
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          # Runs before tmpfiles: /nix/var/nix doesn't exist yet on the RAM root.
          install -d -m 0755 /persist/nix-var /nix/var/nix
          mountpoint -q /nix/var/nix || mount --bind /persist/nix-var /nix/var/nix
          install -d -m 0755 /nix/var/nix/db /nix/var/nix/profiles /nix/var/nix/gcroots
          if [[ "$(cat /proc/cmdline)" =~ regInfo=([^ ]*) ]]; then
            nix-store --load-db <"''${BASH_REMATCH[1]}"
          fi
          # After a guest update, paths only the old store image had are gone:
          # drop them from the database.
          nix-store --verify 2>&1 | tail -n 20 || true
        '';
      };

      # The root filesystem is RAM: builds go to the volume.
      nix.settings.build-dir = "/persist/nix-build";

      systemd.tmpfiles.rules =
        map (f: "L+ ${home}/.claude/${f} - - - - ${home}/.dots/dot-config/claude/${f}") [
          "CLAUDE.md"
          "statusline.sh"
          "hooks"
        ]
        ++ [
          "L+ ${home}/.claude/skills - - - - ${home}/.agents/skills"
          "L+ ${home}/.codex/AGENTS.md - - - - /etc/claude-code/CLAUDE.md"
        ];

      # No way up from dev: no sudo, no root login, locked root password.
      security.sudo.enable = false;
      users.mutableUsers = false;
      users.users.root.hashedPassword = "!";
      # Intentional: root has no way in; dev logs in by key only (no wheel).
      users.allowNoPasswordLogin = true;
      users.users.dev = {
        hashedPassword = "!";
        # Public half of ~/.local/state/devvm/ssh/id_ed25519 on the Mac
        # (devctl). The same key in every guest keeps the closures identical.
        openssh.authorizedKeys.keyFiles = [ ./devvm_ssh.pub ];
      };

      # SSH only over vsock (devctl connects through vfkit's unix socket), one
      # sshd -i per connection; nothing listens on the network.
      services.openssh = {
        enable = true;
        startWhenNeeded = true;
        openFirewall = false;
        hostKeys = [
          {
            path = "/persist/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          AllowUsers = [ "dev" ];
          X11Forwarding = false;
          AllowAgentForwarding = false;
          # The Mac may forward a guest port to itself (ssh -L); the guest gets
          # nothing on the Mac (no -R, no unix-socket forwarding).
          AllowTcpForwarding = "local";
          AllowStreamLocalForwarding = "no";
        };
        extraConfig = ''
          AcceptEnv COLORTERM TZ GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
        '';
      };
      systemd.sockets.sshd.socketConfig.ListenStream = lib.mkForce [ "vsock::22" ];
      systemd.services.sshd-keygen = {
        after = [ "dev-persist-dirs.service" ];
        requires = [ "dev-persist-dirs.service" ];
      };

      # Clock after Mac sleep: vfkit --timesync talks to qemu-ga over vsock.
      services.qemuGuest.enable = true;
      systemd.services.qemu-guest-agent = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = lib.mkForce "${config.services.qemuGuest.package}/bin/qemu-ga --statedir /run/qemu-ga -m vsock-listen -p 4294967295:${toString timesyncPort}";
      };

      # Network: vfkit NAT (vmnet), matched by driver so every guest and MAC
      # gets the same config. IPv4 only.
      networking.useNetworkd = true;
      networking.useDHCP = false;
      networking.firewall.enable = false;
      systemd.network.networks."10-vm" = {
        matchConfig.Driver = "virtio_net";
        # The MAC (unique per project, from devctl) as DHCP client id: vmnet
        # keys leases by it, so every guest gets its own address and devctl
        # can find it. networkd's default DUID would be the same in every guest.
        dhcpV4Config.ClientIdentifier = "mac";
        # vmnet offers the gateway as DNS server, but nothing answers there on
        # this Mac. Public
        # resolvers instead (below); also keeps the Mac's DNS, MagicDNS and LAN
        # names out of the guest.
        dhcpV4Config.UseDNS = false;
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
      };
      boot.kernel.sysctl = {
        "net.ipv6.conf.all.disable_ipv6" = 1;
        "net.ipv6.conf.default.disable_ipv6" = 1;
      };
      services.resolved.settings.Resolve = {
        DNS = "1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net 1.0.0.1#cloudflare-dns.com 149.112.112.112#dns.quad9.net";
        FallbackDNS = "";
        DNSOverTLS = "opportunistic";
        LLMNR = false;
        MulticastDNS = false;
      };

      # Defence in depth only: the Mac-side pf anchor (host-darwin.nix) is the
      # wall. Out: internet yes; LAN, Tailscale (CGNAT), link-local, multicast
      # and the Mac no, except DNS and DHCP to the NAT gateway. In: the Mac
      # (gateway) may reach dev servers here; other guests may not.
      networking.nftables = {
        enable = true;
        tables.dev-egress = {
          family = "inet";
          content = ''
            set gw {
              type ipv4_addr
            }
            set private4 {
              type ipv4_addr
              flags interval
              elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16,
                           172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255 }
            }
            chain output {
              type filter hook output priority 0; policy accept;
              oif lo accept
              ct state established,related accept
              ip daddr @gw meta l4proto { tcp, udp } th dport 53 accept
              ip daddr @gw udp dport 67 accept
              ip daddr 255.255.255.255 udp dport 67 accept
              ip daddr @private4 reject
              icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept
              ip6 daddr { fc00::/7, fe80::/10, ff00::/8 } reject
            }
            chain input {
              type filter hook input priority 0; policy accept;
              iif lo accept
              ct state established,related accept
              ip saddr @gw accept
              udp sport 67 udp dport 68 accept
              ip saddr @private4 drop
              ip6 saddr { fc00::/7, fe80::/10 } drop
            }
          '';
        };
      };
      # The gateway is whatever DHCP handed out (vmnet's subnet is a Mac
      # setting): put it in @gw once the network is up.
      systemd.services.dev-egress-gw = {
        description = "Allow DNS/DHCP to the NAT gateway";
        after = [
          "network-online.target"
          "nftables.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "nftables.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.iproute2
          pkgs.nftables
          pkgs.gawk
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for _ in $(seq 60); do
            gw=$(ip -4 route show default | awk '{ print $3; exit }')
            if [ -n "$gw" ]; then
              nft add element inet dev-egress gw "{ $gw }"
              exit 0
            fi
            sleep 1
          done
          echo "no default route after 60s" >&2
          exit 1
        '';
      };

      # Idle auto-stop: power off after 10 min
      # with nobody connected, or 30 min when only a detached zellij is left
      # and it (agents included) used under ~1.2 s CPU a minute. An SSH session
      # (dev, dev forward) keeps the VM up. `touch /persist/no-idle-stop` turns
      # this off for the project.
      systemd.services.dev-idle-stop = {
        description = "Power off the dev VM when idle";
        path = [
          pkgs.procps
          pkgs.coreutils
          pkgs.gawk
          config.systemd.package
        ];
        serviceConfig.Type = "oneshot";
        script = ''
          [ -e /persist/no-idle-stop ] && exit 0
          d=/run/dev-idle
          mkdir -p "$d"
          attached=0 detached=0
          while read -r args; do
            case $args in
            sshd-session:\ dev@* | sshd:\ dev@*) attached=1 ;;
            *zellij*--server*) detached=1 ;;
            esac
          done < <(ps -eo args= || true)
          cpu=0
          for f in /sys/fs/cgroup/user.slice/user-501.slice/cpu.stat \
            /sys/fs/cgroup/system.slice/nix-daemon.service/cpu.stat; do
            v=$(awk '$1 == "usage_usec" { print $2 }' "$f" 2>/dev/null || true)
            cpu=$((cpu + ''${v:-0}))
          done
          prev=$(cat "$d/cpu" 2>/dev/null || echo "$cpu")
          echo "$cpu" >"$d/cpu"
          if ((attached || cpu - prev > 1200000)); then
            rm -f "$d/since"
            exit 0
          fi
          [ -e "$d/since" ] || { touch "$d/since"; exit 0; }
          limit=600
          ((detached)) && limit=1800
          age=$(($(date +%s) - $(stat -c %Y "$d/since")))
          if ((age >= limit)); then
            echo "idle for ''${age}s: powering off"
            systemctl poweroff
          fi
        '';
      };
      systemd.timers.dev-idle-stop = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1min";
        };
      };

      # Weekly `uv cache prune`, tracked by a stamp on /persist (timers' own
      # state is on the RAM root, so OnCalendar=weekly would rarely fire).
      systemd.services.dev-maintenance = {
        description = "Prune the uv cache weekly";
        unitConfig.RequiresMountsFor = "${home}/.cache ${home}/.local/state";
        path = [
          pkgs.uv
          pkgs.coreutils
        ];
        environment.HOME = home;
        serviceConfig = {
          Type = "oneshot";
          User = "dev";
          Group = "users";
          Nice = 10;
        };
        script = ''
          stamp=$HOME/.local/state/dev-maintenance/uv-prune
          if [ ! -e "$stamp" ] || (($(date +%s) - $(stat -c %Y "$stamp") >= 604800)); then
            uv cache prune
            mkdir -p "''${stamp%/*}"
            touch "$stamp"
          fi
        '';
      };
      systemd.timers.dev-maintenance = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15min";
          OnUnitActiveSec = "1d";
        };
      };

      # Claude settings from this boot's dotfiles copy (_guest-common.nix).
      systemd.services.dev-claude-sync = {
        description = "Claude settings from the dotfiles";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = "${home}/.claude ${home}/.dots";
        environment = {
          HOME = home;
          CLAUDE_CONFIG_DIR = "${home}/.claude";
        };
        serviceConfig = {
          Type = "oneshot";
          User = "dev";
          Group = "users";
          ExecStart = "/run/current-system/sw/bin/dev-claude-sync";
        };
      };

      documentation.enable = false;
    };

  flake.checks.aarch64-linux =
    let
      guest = config.flake.nixosConfigurations.dev-guest.config;
    in
    {
      dev-guest = guest.system.build.toplevel;
      dev-guest-store = guest.microvm.storeDisk;
    };
}
