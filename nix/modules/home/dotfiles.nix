# Links this checkout into $HOME on every switch (replaces GNU Stow).
# The links are out-of-store symlinks to the live checkout, so edits apply
# without a rebuild. *Which* paths get linked is read from the flake's copy of
# the repo, i.e. git-tracked files only: `git add` a new config dir before `darnix`.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dotfiles;
  home = config.home.homeDirectory;
  src = "${inputs.self}/..";

  junk = [
    ".DS_Store"
    ".gitignore"
    ".gitkeep"
  ];
  entries =
    dir:
    lib.optionals (builtins.pathExists "${src}/${dir}") (
      lib.subtractLists junk (builtins.attrNames (builtins.readDir "${src}/${dir}"))
    );

  # Submodules aren't in the flake's copy of the repo; .gitmodules lists them.
  submodules = lib.concatMap (
    line:
    let
      m = builtins.match "[[:space:]]*path = (.*)" line;
    in
    lib.optional (m != null) (builtins.head m)
  ) (lib.splitString "\n" (builtins.readFile "${src}/.gitmodules"));
  submodulesIn = dir: map baseNameOf (lib.filter (p: dirOf p == dir) submodules);

  # target (relative to $HOME) → absolute path it links to
  linkEach =
    target: dir: names:
    lib.listToAttrs (map (n: lib.nameValuePair "${target}/${n}" "${cfg.repoRoot}/${dir}/${n}") names);

  # Apps also write their own state into these dirs, so each child is linked
  # instead of the whole dir.
  mergeDirs = [
    "Code/User"
    "opencode"
    "zed"
  ];
  topLevel = map (d: lib.head (lib.splitString "/" d)) mergeDirs;

  links = {
    ".agents" = "${cfg.repoRoot}/dot-agents";
  }
  // linkEach ".config" "dot-config" (lib.subtractLists topLevel (entries "dot-config"))
  // lib.mergeAttrsList (
    map (d: linkEach ".config/${d}" "dot-config/${d}" (entries "dot-config/${d}")) mergeDirs
  )
  // linkEach ".local/share" "dot-local/share" (
    lib.unique (entries "dot-local/share" ++ submodulesIn "dot-local/share")
  )
  # ~/.claude also holds Claude Code's runtime state (sessions, plugins,
  # history), so only the entries dot-config/claude ships are linked in.
  // linkEach ".claude" "dot-config/claude" (entries "dot-config/claude")
  # VS Code reads its settings from ~/Library, not ~/.config.
  // lib.optionalAttrs (lib.elem "Code" (entries "dot-config")) {
    "Library/Application Support/Code/User" = "${home}/.config/Code/User";
  };
in
{
  options.dotfiles = {
    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${home}/dotfiles";
      description = ''
        Live dotfiles checkout on disk (e.g. ~/dotfiles).
        Override in the host module if the repo lives elsewhere.
      '';
    };

    links = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = links;
      description = "Links this module creates: path under $HOME → what it points at. Read by doctor.nix.";
    };
  };

  config = {
    home.file =
      lib.mapAttrs (_: path: { source = config.lib.file.mkOutOfStoreSymlink path; }) links
      // {
        # zsh reads everything else from ZDOTDIR (dot-config/zsh).
        ".zshenv".text = ''
          export ZDOTDIR="$HOME/.config/zsh"
        '';
        # ZSH in .zshenv points here. The store is read-only, so oh-my-zsh
        # keeps its cache in ~/.cache/oh-my-zsh and skips self-updates.
        ".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
      };

    # Symlinks left at these paths by GNU Stow (or by hand) are replaced rather
    # than backed up as *.hm-bak. Only symlinks: a real file or directory in
    # the way is still backed up by Home Manager.
    home.activation.dotfilesReplaceLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for target in ${lib.escapeShellArgs (map (t: "${home}/${t}") (lib.attrNames links))}; do
        if [[ -L $target && $(readlink "$target") != /nix/store/* ]]; then
          run rm "$target"
        fi
      done
    '';
  };
}
