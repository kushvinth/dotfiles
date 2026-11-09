# Linux-specific checks contributed to `dotfiles-doctor`.
{ ... }:
{
  dotfiles.doctor.checks = {
    "linux-systemd" = ''
      if command -v systemctl >/dev/null 2>&1; then
        echo "systemd user services"
        failed="$(systemctl --user --failed --quiet || true)"
        if [ -z "$failed" ]; then
          ok "no failed systemd user units"
        else
          warn "failed user units detected: $failed"
        fi
      fi
    '';
  };
}
