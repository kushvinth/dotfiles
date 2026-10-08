{ ... }:
{
  # Touch ID for sudo (via /etc/pam.d/sudo_local, survives macOS updates).
  # reattach: also works inside tmux/zellij sessions.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };
}
