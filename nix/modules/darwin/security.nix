{ user, ... }:
{
  # Touch ID for sudo (via /etc/pam.d/sudo_local, survives macOS updates).
  # reattach: also works inside tmux/zellij sessions.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # rolock (Hammerspoon readonly.lua) keeps the Mac awake with the lid closed while locked,
  # via `pmset disablesleep`. Exactly these two commands, nothing else.
  security.sudo.extraConfig = ''
    ${user} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
  '';

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
