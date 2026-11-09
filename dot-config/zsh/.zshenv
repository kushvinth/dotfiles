# PATH, NIX_PROFILES, ZDOTDIR etc. come from nix-darwin's /etc/zshenv
# (set-environment + programs.zsh.shellInit in nix/modules/darwin/system.nix).
# Don't prepend nix paths here: /etc/zshenv already puts them first.
export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

case "$OSTYPE" in
  darwin*) [[ -r "$ZDOTDIR/zshenv.darwin" ]] && source "$ZDOTDIR/zshenv.darwin" ;;
  linux*)  [[ -r "$ZDOTDIR/zshenv.linux" ]]  && source "$ZDOTDIR/zshenv.linux" ;;
esac

export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"
[[ -d ${ZSH_COMPDUMP:h} ]] || mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$ZDOTDIR/assets/custom"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/.lmstudio/bin"
export PATH="/usr/local/sbin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Local LLM proxy (nothing listens on :8080 by default). Exporting these globally
# breaks Claude Code / the SDK whenever the proxy is down; enable per project instead.
# export ANTHROPIC_BASE_URL="http://localhost:8080"
# export ANTHROPIC_AUTH_TOKEN="test"

# Ghostty does not provide terminfo, so fall back to xterm-256color
if [[ "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty &>/dev/null; then
  export TERM=xterm-256color
fi
