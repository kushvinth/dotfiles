# PATH, NIX_PROFILES, ZDOTDIR etc. come from nix-darwin's /etc/zshenv
# (set-environment + programs.zsh.shellInit in nix/modules/darwin/system.nix).
# Don't prepend nix paths here: /etc/zshenv already puts them first.
export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

# Skip nix-darwin's /etc/zshrc (its compinit clashes with oh-my-zsh's).
# /etc/zshenv still runs, so nix env/fpath are intact.
export NOSYSZSHRC=1

export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"
mkdir -p "$(dirname "$ZSH_COMPDUMP")" 2>/dev/null

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$ZDOTDIR/assets/custom"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
export FZF_BASE="/run/current-system/sw/share/fzf"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$HOME/.lmstudio/bin"
export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

export HOMEBREW_NO_ENV_HINTS=1
# Local LLM proxy (nothing listens on :8080 by default). Exporting these globally
# breaks Claude Code / the SDK whenever the proxy is down; enable per project instead.
# export ANTHROPIC_BASE_URL="http://localhost:8080"
# export ANTHROPIC_AUTH_TOKEN="test"

export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null)"
[[ -n "$JAVA_HOME" ]] && export PATH="$JAVA_HOME/bin:$PATH"

# Ghostty does not provide terminfo, so fall back to xterm-256color
if [[ "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty &>/dev/null; then
  export TERM=xterm-256color
fi
