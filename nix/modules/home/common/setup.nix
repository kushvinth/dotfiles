# Universal setup re-checked on every switch after symlinks are in place.
# Each step only warns on failure: a network blip or missing key shouldn't abort activation.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  repo = lib.escapeShellArg config.dotfiles.repoRoot;
  git = lib.getExe pkgs.git;
in
{
  home.activation = {
    # Clones submodules that were never cloned ("-" in `git submodule status`).
    # Existing ones are left alone: `submodule update` would reset them to the
    # recorded commit and lose work in progress. Updating stays manual
    # (`git submodule update --remote`).
    dotfilesSubmodules = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if submodules=$(${git} -C ${repo} submodule status --recursive 2>/dev/null); then
        while read -r state path _; do
          [[ $state == -* ]] || continue
          run timeout 300 ${git} -C ${repo} submodule update --init --recursive -- "$path" ||
            warnEcho "dotfiles: could not clone submodule $path"
        done <<<"$submodules"
      else
        warnEcho "dotfiles: no git checkout at ${repo}"
      fi
    '';

    # Themes come from the bat/assets submodule.
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
  };
}
