{
  flake.modules.darwin.security =
    { user, ... }:
    {
      security.pam.services.sudo_local = {
        touchIdAuth = true;
        reattach = true;
      };
      # rolock (Hammerspoon readonly.lua) keeps the Mac awake with the lid closed while locked,
      # via `pmset disablesleep`. Exactly these two commands, nothing else.
      security.sudo.extraConfig = ''
        ${user} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
      '';
      networking.applicationFirewall = {
        enable = true;
        enableStealthMode = true;
        allowSigned = true;
        allowSignedApp = true;
      };

      system.defaults = {
        screensaver = {
          askForPassword = true;
          askForPasswordDelay = 0;
        };
        loginwindow.GuestEnabled = false;

        CustomSystemPreferences."com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          AutomaticDownload = true;
          CriticalUpdateInstall = true;
          ConfigDataInstall = true;
        };
      };
    };
}
