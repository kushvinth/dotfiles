# Setup that is re-checked on every switch, after the links are in place. Each
# step only warns on failure: a network blip shouldn't abort the switch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  repo = lib.escapeShellArg config.dotfiles.repoRoot;
  git = lib.getExe pkgs.git;
  mas = lib.getExe pkgs.mas;

  # App Store apps. Not homebrew.masApps: under `sudo darwin-rebuild` brew
  # bundle can't find mas and aborts activation. Missing apps are installed;
  # the App Store's automatic updates keep them current.
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
  home.activation = {
    # Clones submodules that were never cloned ("-" in `git submodule status`).
    # Existing ones are left alone: `submodule update` would reset them to the
    # recorded commit and lose work in progress. Updating stays manual
    # (`git submodule update --remote`).
    dotfilesSubmodules = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if submodules=$(${git} -C ${repo} submodule status --recursive); then
        while read -r state path _; do
          [[ $state == -* ]] || continue
          run timeout 300 ${git} -C ${repo} submodule update --init --recursive -- "$path" ||
            warnEcho "dotfiles: could not clone submodule $path"
        done <<<"$submodules"
      else
        warnEcho "dotfiles: no git checkout at ${repo}"
      fi
    '';

    # Themes come from the bat/asserts submodule.
    dotfilesBatCache = lib.hm.dag.entryAfter [ "dotfilesSubmodules" ] ''
      run --quiet ${lib.getExe pkgs.bat} cache --build || warnEcho "dotfiles: bat cache --build failed"
    '';

    # Only plugins missing from disk, at their lazy-lock.json commit; updating
    # stays manual (`:Lazy sync`). curl is for build steps that download
    # (Cord.nvim's `:Cord update`).
    dotfilesNvimPlugins = lib.hm.dag.entryAfter [ "dotfilesSubmodules" ] ''
      run env PATH=${
        lib.makeBinPath [
          pkgs.git
          pkgs.curl
        ]
      }:"$PATH" \
        timeout 300 ${lib.getExe pkgs.neovim} --headless '+Lazy! install' +qa ||
        warnEcho "dotfiles: nvim plugin install failed"
    '';

    dotfilesAppStore = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      installed=$(${mas} list 2>/dev/null || true)
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: id: ''
          if ! grep -Eq '^ *${toString id} ' <<<"$installed"; then
            run ${mas} install ${toString id} || warnEcho ${lib.escapeShellArg "dotfiles: could not install ${name} from the App Store"}
          fi
        '') appStoreApps
      )}
    '';
  };
}
