{
  writeShellApplication,
  coreutils,
  findutils,
  gnused,
  gawk,
  stow,
  git,
  bat,
  neovim,
}:
writeShellApplication {
  name = "dotfiles";
  runtimeInputs = [
    coreutils
    findutils
    gnused
    gawk
    stow
    git
    bat
    neovim
  ];
  text = ''
        repo_root="''${DOTFILES_REPO_ROOT:-$HOME/dotfiles}"
        home_dir="''${HOME:?HOME must be set}"
        config_dir="$repo_root/assets/configs"
        completion_dir="$home_dir/.config/zsh/completions"

        require_repo() {
          if [ ! -d "$repo_root/.git" ]; then
            echo "dotfiles: repository not found at $repo_root" >&2
            exit 1
          fi
        }

        stow_sentinels() {
          mkdir -p "$home_dir/.config/Code/User" "$home_dir/.config/Cursor/User" "$home_dir/.local/share"
          touch "$home_dir/.config/Code/User/.stow-keep" "$home_dir/.config/Cursor/User/.stow-keep" "$home_dir/.local/share/.stow-keep"
        }

        remove_stow_sentinels() {
          rm -f "$home_dir/.config/Code/User/.stow-keep" "$home_dir/.config/Cursor/User/.stow-keep" "$home_dir/.local/share/.stow-keep"
        }

        link_editor_configs() {
          for editor in Code Cursor; do
            source="$home_dir/.config/$editor/User"
            destination="$home_dir/Library/Application Support/$editor/User"
            if [ -d "$source" ]; then
              mkdir -p "$home_dir/Library/Application Support/$editor"
              if [ -d "$destination" ] && [ ! -L "$destination" ]; then
                mv "$destination" "$destination.bak"
                echo "dotfiles: backed up $destination to $destination.bak" >&2
              fi
              ln -sfn "$source" "$destination"
            fi
          done
        }

        stow_dotfiles() {
          require_repo
          echo "dotfiles: stowing into $home_dir" >&2
          stow_sentinels
          trap remove_stow_sentinels RETURN
          stow --dir "$repo_root" --target "$home_dir" --dotfiles --verbose="''${VERBOSITY:-1}" .
          link_editor_configs
          if [ ! -f "$home_dir/.zshenv" ]; then
        printf '%s\n' "export ZDOTDIR=\$HOME/.config/zsh" > "$home_dir/.zshenv"
          fi
        }

        unstow_dotfiles() {
          require_repo
          stow -D --dir "$repo_root" --target "$home_dir" --dotfiles --verbose="''${VERBOSITY:-1}" .
          for editor in Code Cursor; do
            destination="$home_dir/Library/Application Support/$editor/User"
            [ ! -L "$destination" ] || rm -f "$destination"
          done
        }

        install_etc() {
          require_repo
          find "$config_dir/etc" -type f -print | while IFS= read -r file; do
            destination="''${file#"$config_dir"}"
            mode=644; [ -x "$file" ] && mode=755
            sudo install -m "$mode" -o root -g wheel "$file" "$destination"
          done
        }

        get_etc() {
          require_repo
          find "$config_dir/etc" -type f -print | while IFS= read -r file; do
            source="''${file#"$config_dir"}"
            if [ -f "$source" ]; then sudo cp "$source" "$file"; else echo "dotfiles: skip missing $source" >&2; fi
          done
        }

        update_submodules() {
          require_repo
          git -C "$repo_root" submodule update --init --recursive
          git -C "$repo_root" submodule foreach --recursive 'git pull --ff-only 2>/dev/null || true'
        }

        update_nvim() {
          require_repo
          nvim --headless '+Lazy! sync' +qa
          if ! git -C "$repo_root" diff --quiet -- dot-config/nvim/lazy-lock.json; then
        git -C "$repo_root" commit dot-config/nvim/lazy-lock.json -m "chore(nvim): update lazy-lock" || \
          echo "dotfiles: could not commit lazy-lock.json; leaving it for manual review" >&2
          fi
        }

        update_completions() {
          require_repo
          mkdir -p "$completion_dir"
          find "$completion_dir" -maxdepth 1 -type l ! -exec test -e {} \; -delete
          for file in /run/current-system/sw/share/zsh/site-functions/_*; do
            [ -f "$file" ] || continue
            command_name="$(basename "$file" | sed 's/^_//')"
            command -v "$command_name" >/dev/null 2>&1 && ln -sf "$file" "$completion_dir/_$command_name"
          done
          if [ -d /opt/homebrew/share/zsh/site-functions ]; then
            find /opt/homebrew/share/zsh/site-functions -maxdepth 1 \( -type f -o -type l \) -name '_*' -print | while IFS= read -r file; do
              command_name="$(basename "$file" | sed 's/^_//')"
              command -v "$command_name" >/dev/null 2>&1 && ln -sf "$file" "$completion_dir/_$command_name"
            done
          fi
      if [ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ] && [ ! -f "$completion_dir/_docker" ] && [ ! -L "$completion_dir/_docker" ]; then ln -sf /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion "$completion_dir/_docker"; fi
      if [ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ] && command -v docker-compose >/dev/null 2>&1 && [ ! -f "$completion_dir/_docker-compose" ] && [ ! -L "$completion_dir/_docker-compose" ]; then ln -sf /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion "$completion_dir/_docker-compose"; fi
          for tool in bat gh uv deno docker podman tailscale git-lfs; do
            command -v "$tool" >/dev/null 2>&1 || continue
            [ -e "$completion_dir/_$tool" ] && continue
            case "$tool" in
              bat) bat --completion zsh > "$completion_dir/_bat" ;;
              gh) gh completion -s zsh > "$completion_dir/_gh" ;;
              uv) uv generate-shell-completion zsh > "$completion_dir/_uv" ;;
              deno) deno completions zsh > "$completion_dir/_deno" ;;
              docker) docker completion zsh > "$completion_dir/_docker" ;;
              podman) podman completion zsh > "$completion_dir/_podman" ;;
              tailscale) tailscale completion zsh > "$completion_dir/_tailscale" ;;
              git-lfs) git-lfs completion zsh > "$completion_dir/_git-lfs" ;;
            esac
          done
          if command -v brew >/dev/null 2>&1; then
            mkdir -p "$repo_root/dot-config/zsh/assets/generated"
        if [ -f /run/current-system/sw/share/zsh/site-functions/_brew ]; then
          rm -f "$repo_root/dot-config/zsh/assets/generated/_brew"
          ln -sf /run/current-system/sw/share/zsh/site-functions/_brew "$completion_dir/_brew"
        elif [ -f /opt/homebrew/share/zsh/site-functions/_brew ]; then
          rm -f "$repo_root/dot-config/zsh/assets/generated/_brew"
          ln -sf /opt/homebrew/share/zsh/site-functions/_brew "$completion_dir/_brew"
            else
              { printf '#compdef brew\n_brew() {\n  local -a cmds\n  cmds=(\n'; brew commands | awk '{print "    \"" $1 "\""}'; printf '  )\n  _describe brew cmds\n}\n_brew "$@"\n'; } > "$repo_root/dot-config/zsh/assets/generated/_brew"
              ln -sf ../assets/generated/_brew "$completion_dir/_brew"
            fi
          fi
          [ ! -e "$completion_dir/_uv" ] || ln -sf _uv "$completion_dir/_uvx"
          rm -f "$home_dir/.zcompdump"
        }

    setup() {
      require_repo
      git -C "$repo_root" submodule update --init --recursive
      bat cache --build
      nvim --headless '+Lazy! restore' +qa
      update_completions
    }

    activate() {
      stow_dotfiles
      update_submodules
      bat cache --build
      nvim --headless '+Lazy! restore' +qa
      update_nvim
      update_completions
    }

        usage() { cat <<'EOF'
    Usage: dotfiles <target>

    Targets: activate install stow unstow restow etc get-etc setup update
             update-submodules update-nvim update-completions
    EOF
        }

    case "''${1:-help}" in
      activate) activate ;;
      install) stow_dotfiles; update_submodules; update_completions ;;
          stow) stow_dotfiles ;;
          unstow) unstow_dotfiles ;;
          restow) unstow_dotfiles; stow_dotfiles ;;
          etc) install_etc ;;
          get-etc) get_etc ;;
          setup) setup ;;
          update) update_submodules; update_nvim ;;
          update-submodules) update_submodules ;;
          update-nvim) update_nvim ;;
          update-completions) update_completions ;;
          help|--help|-h) usage ;;
          *) echo "dotfiles: unknown target: $1" >&2; usage >&2; exit 2 ;;
        esac
  '';
}
