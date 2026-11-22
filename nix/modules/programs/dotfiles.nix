{ dotfilesLib, ... }:
{
  flake.modules.homeManager.dotfiles =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dotfiles;
      home = config.home.homeDirectory;
      src = dotfilesLib.repoRoot;

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

      submodules = lib.concatMap (
        line:
        let
          m = builtins.match "[[:space:]]*path = (.*)" line;
        in
        lib.optional (m != null) (builtins.head m)
      ) (lib.splitString "\n" (builtins.readFile "${src}/.gitmodules"));
      submodulesIn = dir: map baseNameOf (lib.filter (p: dirOf p == dir) submodules);

      linkEach =
        target: dir: names:
        lib.listToAttrs (map (n: lib.nameValuePair "${target}/${n}" "${cfg.repoRoot}/${dir}/${n}") names);

      mergeDirs = [
        "Code/User"
        "opencode"
        "zed"
      ];
      topLevel = map (d: lib.head (lib.splitString "/" d)) mergeDirs;

      darwinOnly = [
        "aerospace"
        "borders"
        "hammerspoon"
        "karabiner"
        "linearmouse"
        "raycast"
        "sketchybar"
        "skhd"
        "yabai"
      ];
      excludedTopLevel = topLevel ++ (lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) darwinOnly);

      hasDir = d: builtins.pathExists "${src}/dot-config/${d}";
      darwinLinks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
        { }
        // lib.optionalAttrs (hasDir "Code") {
          "Library/Application Support/Code/User" = "${home}/.config/Code/User";
        }
        // lib.optionalAttrs (hasDir "lazygit") {
          "Library/Application Support/lazygit/config.yml" = "${home}/.config/lazygit/config.yml";
        }
        // lib.optionalAttrs (hasDir "hammerspoon") {
          ".hammerspoon" = "${home}/.config/hammerspoon";
        }
      );

      links = {
        ".agents" = "${cfg.repoRoot}/dot-agents";
      }
      // linkEach ".config" "dot-config" (lib.subtractLists excludedTopLevel (entries "dot-config"))
      // lib.mergeAttrsList (
        map (d: linkEach ".config/${d}" "dot-config/${d}" (entries "dot-config/${d}")) mergeDirs
      )
      // linkEach ".local/share" "dot-local/share" (
        lib.unique (entries "dot-local/share" ++ submodulesIn "dot-local/share")
      )
      // linkEach ".claude" "dot-config/claude" (entries "dot-config/claude");
    in
    {
      options.dotfiles = {
        repoRoot = lib.mkOption {
          type = lib.types.str;
          default = "${home}/dotfiles";
          description = "Live dotfiles checkout on disk (e.g. ~/dotfiles).";
        };

        links = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = links;
          description = "Links this module creates: path under $HOME → what it points at.";
        };
      };

      config = {
        home.file =
          lib.mapAttrs (_: path: {
            source = config.lib.file.mkOutOfStoreSymlink path;
            force = true;
          }) (config.dotfiles.links // darwinLinks)
          // {
            ".oh-my-zsh" = {
              source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
              force = true;
            };
          };

        home.activation.dotfilesReplaceLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          for target in ${
            lib.escapeShellArgs (map (t: "${home}/${t}") (lib.attrNames config.dotfiles.links))
          }; do
            if [[ -L $target && $(readlink "$target") != /nix/store/* ]]; then
              run rm "$target"
            fi
            if [[ -e "$target.hm-bak" ]]; then
              run rm -f "$target.hm-bak"
            fi
          done
        '';

        home.activation.claudeSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p "${home}/.claude/skills"
          for skill in "${cfg.repoRoot}"/dot-agents/skills/*/; do
            skill=''${skill%/}
            [[ -f $skill/SKILL.md ]] || continue
            target="${home}/.claude/skills/''${skill##*/}"
            [[ -e $target && ! -L $target ]] || run ln -sfn "$skill" "$target"
          done
        '';
      };
    };
}
