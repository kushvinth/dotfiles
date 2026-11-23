{
  flake.modules.homeManager.setup =
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

        dotfilesBatCache = lib.hm.dag.entryAfter [ "dotfilesSubmodules" ] ''
          run --quiet ${lib.getExe pkgs.bat} cache --build || warnEcho "dotfiles: bat cache --build failed"
        '';

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
    };
}
