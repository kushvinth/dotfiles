export PATH="/run/current-system/sw/bin:$PATH"

export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

# Skip nix-darwin's /etc/zshrc (and its broken compinit).
export NOSYSZSHRC=1

# Source nix daemon manually since NOSYSZSHRC skips /etc/zshrc.
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"
mkdir -p "$(dirname "$ZSH_COMPDUMP")" 2>/dev/null

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$ZDOTDIR/assets/custom"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$HOME/.lmstudio/bin"
export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

export HOMEBREW_NO_ENV_HINTS=1
export ANTHROPIC_BASE_URL="http://localhost:8080"
export ANTHROPIC_AUTH_TOKEN="test"

export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null)"
[[ -n "$JAVA_HOME" ]] && export PATH="$JAVA_HOME/bin:$PATH"
