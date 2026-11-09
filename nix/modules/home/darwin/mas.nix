# App Store apps management via `mas`.
# Kept as a user-level Home Manager activation hook because brew bundle under sudo
# cannot access the user's Mac App Store session.
{
  lib,
  pkgs,
  ...
}:
let
  mas = lib.getExe pkgs.mas;

  appStoreApps = {
    "Battery Health 2" = 1120214373;
    "CleanMyKeyboard" = 6468120888;
    "Delete Apps" = 1033808943;
    "iMovie" = 408981434;
    "Microsoft Excel" = 462058435;
    "Microsoft PowerPoint" = 462062816;
    "Microsoft Word" = 462054704;
    # RunCat (1429033973) was pulled from the App Store; mas can no longer fetch it
    # Slack comes from the Homebrew cask (homebrew.nix), not the App Store.
    "Tailscale" = 1475387142;
    "The Unarchiver" = 425424353;
    "Xcode" = 497799835;
  };
in
{
  home.activation.dotfilesAppStore = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    installed=$(${mas} list 2>/dev/null || true)
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: id: ''
        if ! grep -Eq '^ *${toString id} ' <<<"$installed"; then
          run ${mas} install ${toString id} || warnEcho ${lib.escapeShellArg "dotfiles: could not install ${name} from the App Store"}
        fi
      '') appStoreApps
    )}
  '';
}
