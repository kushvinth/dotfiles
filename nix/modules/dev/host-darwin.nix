# Mac side of the per-project `dev` microVMs (README.md): the Linux builder
# that builds the guest, vfkit + devctl, the guest's boot artefacts, and the
# pf anchor that walls the VMs off from the LAN, Tailscale and the Mac.
# Imported by hosts/MacbookPro.nix.
{ config, lib, ... }:
let
  guest = config.flake.nixosConfigurations.dev-guest;
in
{
  perSystem =
    { pkgs, ... }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      devctl = pkgs.writeShellApplication {
        name = "devctl";
        runtimeInputs = with pkgs; [
          vfkit
          socat
          openssh
          rsync
          git
          coreutils
          findutils
          gnused
          gawk
          gnugrep
          curl
        ];
        text = builtins.readFile ./devctl.sh;
      };
    in
    {
      packages = lib.optionalAttrs isDarwin { inherit devctl; };
      overlayAttrs = lib.optionalAttrs isDarwin { inherit devctl; };
    };

  flake.modules.darwin.devvm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.devvm;
      g = guest.config;
      # What devctl passes vfkit (lib/runners/vfkit.nix in microvm.nix). The
      # cmdline names the toplevel and closure registration, which live inside
      # the store image: dropping their context keeps the guest closure off the
      # Mac, which only gets the kernel, initrd and erofs image.
      bootEnv = pkgs.writeText "dev-guest.env" ''
        KERNEL=${g.microvm.kernel.out}/${g.microvm.kernel.target}
        INITRD=${g.microvm.initrdPath}
        CMDLINE=${lib.escapeShellArg (builtins.unsafeDiscardStringContext (lib.concatStringsSep " " g.microvm.kernelParams))}
        STOREDISK=${g.microvm.storeDisk}
      '';

      anchor = "com.apple/250.devvm";
      statusFile = "/var/run/devvm-pf.status";
      vmnetPlist = "/Library/Preferences/SystemConfiguration/com.apple.vmnet.plist";

      # NOTE: Apple does not treat pf as an API. macOS updates (and anything
      # that reloads /etc/pf.conf without the com.apple anchor point) can reset
      # it. This daemon re-applies the rules every 30 s and devctl refuses to
      # boot a VM unless its status file is fresh and says "loaded".
      pfScript = pkgs.writeShellApplication {
        name = "devvm-pf";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          status=${statusFile}
          tokenf=/var/run/devvm-pf.token
          anchor=${anchor}
          plist=${vmnetPlist}

          report() {
            printf '%s %s %s\n' "$1" "$(date +%s)" "$2" >"$status.tmp"
            chmod 0644 "$status.tmp"
            mv -f "$status.tmp" "$status"
          }
          fail() {
            report failed "$*"
            echo "devvm-pf: $*" >&2
            exit 1
          }

          # vmnet's shared (NAT) subnet: a Mac setting, 192.168.64.0/24 by default.
          gw=192.168.64.1 mask=255.255.255.0
          if [[ -r $plist ]]; then
            v=$(/usr/libexec/PlistBuddy -c 'Print :Shared_Net_Address' "$plist" 2>/dev/null) && gw=$v
            v=$(/usr/libexec/PlistBuddy -c 'Print :Shared_Net_Mask' "$plist" 2>/dev/null) && mask=$v
          fi
          [[ $gw =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || fail "bad vmnet address: $gw"
          g=("''${BASH_REMATCH[@]:1}")
          [[ $mask =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || fail "bad vmnet mask: $mask"
          m=("''${BASH_REMATCH[@]:1}")
          prefix=0
          n4=()
          for i in 0 1 2 3; do
            o=''${m[i]}
            while ((o & 128)); do
              prefix=$((prefix + 1))
              o=$(((o << 1) & 255))
            done
            n4+=($((g[i] & m[i])))
          done
          subnet=''${n4[0]}.''${n4[1]}.''${n4[2]}.''${n4[3]}/$prefix

          # vmnet's bridges (bridge100 for the first VM, more if needed).
          bridges=$(/sbin/ifconfig -l | tr ' ' '\n' | grep -E '^bridge1[0-9]{2}$' | tr '\n' ' ' || true)
          bridges="{ bridge100 ''${bridges} }"

          rules=$(
            cat <<EOF
          # devvm (nix/modules/dev/host-darwin.nix): guests on $subnet get the
          # internet, DNS and DHCP from the gateway, and nothing else local.
          table <devvm_local> const { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255 }
          # The Mac may reach dev servers in a guest; replies match this state.
          pass out quick inet from any to $subnet keep state
          pass in quick inet proto { udp tcp } from $subnet to $gw port 53 keep state
          pass in quick inet proto udp from { $subnet 0.0.0.0 } port 68 to { $gw 255.255.255.255 } port 67 keep state
          block return in quick inet from $subnet to <devvm_local>
          block return in quick inet from $subnet to self
          block return in quick on $bridges inet6 from any to { fc00::/7 fe80::/10 ff00::/8 }
          block return in quick on $bridges inet6 from any to self
          EOF
          )

          # Guest-to-guest traffic is bridged inside vmnet; ask the bridge to
          # pass it through pf too (best effort; the guests' nftables also
          # drop it).
          /usr/sbin/sysctl -w net.link.bridge.pfil_member=1 net.link.bridge.pfil_bridge=1 >/dev/null 2>&1 || true

          /sbin/pfctl -s rules 2>/dev/null | grep -qF 'anchor "com.apple/*"' ||
            fail "the main pf ruleset has no com.apple/* anchor point (was /etc/pf.conf replaced?)"
          printf '%s\n' "$rules" | /sbin/pfctl -q -a "$anchor" -f - || fail "pfctl rejected the $anchor rules"

          # Our own enable reference: pf stays on even if another tool drops
          # its token (pfctl -X).
          token=$(cat "$tokenf" 2>/dev/null || true)
          if [[ -z $token ]] || ! /sbin/pfctl -s References 2>/dev/null | grep -qw -- "$token"; then
            token=$(/sbin/pfctl -E 2>&1 | sed -n 's/.*Token : \([0-9][0-9]*\).*/\1/p')
            [[ -n $token ]] || fail "pfctl -E returned no token"
            printf '%s\n' "$token" >"$tokenf"
          fi

          /sbin/pfctl -s info 2>/dev/null | grep -q 'Status: Enabled' || fail "pf is not enabled"
          n=$(/sbin/pfctl -a "$anchor" -s rules 2>/dev/null | grep -c . || true)
          ((n > 0)) || fail "the $anchor anchor has no rules"
          report loaded "subnet=$subnet gw=$gw rules=$n token=$token"
        '';
      };
    in
    {
      options.devvm.guestBootEnv = lib.mkOption {
        type = lib.types.package;
        default = bootEnv;
        defaultText = lib.literalMD "kernel, initrd, cmdline and store disk of `nixosConfigurations.dev-guest`";
        description = ''
          Env file devctl reads (KERNEL, INITRD, CMDLINE, STOREDISK). CI swaps in
          a stub, because macOS runners can't build the Linux guest.
        '';
      };

      config = {
        # Builds the aarch64-linux guest on darwin-rebuild. Ephemeral: a fresh
        # builder VM every start, nothing kept between builds.
        nix.linux-builder = {
          enable = true;
          ephemeral = true;
          maxJobs = 4;
          config.virtualisation = {
            darwin-builder.memorySize = 8192;
            # The guest closure (~7.5 GiB) plus its erofs image (~3.6 GiB) don't
            # fit the default 20 GiB: the builder's auto-GC then deletes store
            # paths mkfs.erofs is still packing, and the store disk build fails
            # at random. Sparse, and wiped on every start (ephemeral).
            darwin-builder.diskSize = 81920;
            cores = 6;
          };
        };

        environment.systemPackages = [
          pkgs.vfkit
          pkgs.socat
          pkgs.devctl
        ];
        environment.etc."devvm/guest.env".source = cfg.guestBootEnv;

        launchd.daemons.devvm-pf = {
          serviceConfig = {
            ProgramArguments = [ (lib.getExe pfScript) ];
            RunAtLoad = true;
            StartInterval = 30;
            WatchPaths = [ vmnetPlist ];
            StandardOutPath = "/var/log/devvm-pf.log";
            StandardErrorPath = "/var/log/devvm-pf.log";
          };
        };
      };
    };
}
