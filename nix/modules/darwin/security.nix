{ ... }:
{
  # Touch ID for sudo (via /etc/pam.d/sudo_local, survives macOS updates).
  # reattach: also works inside tmux/zellij sessions.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Application firewall: signed apps may listen, nothing answers pings/probes.
  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
    allowSigned = true;
    allowSignedApp = true;
  };

  system.defaults = {
    # Lock immediately when the screensaver starts or the display sleeps.
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };
    loginwindow.GuestEnabled = false;

    # Security responses and XProtect/MRT data install on their own; macOS
    # upgrades themselves stay manual.
    CustomSystemPreferences."com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      AutomaticDownload = true;
      CriticalUpdateInstall = true;
      ConfigDataInstall = true;
    };
  };
}
