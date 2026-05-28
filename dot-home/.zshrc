# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
export PATH="$PATH:/Users/MacbookPro/.local/bin"
ZSH_THEME=""

# Plugins
plugins=(
  git
  sudo
  you-should-use
  starship
  man
  colored-man-pages
  fzf
  forgit
)

source "$ZSH/oh-my-zsh.sh"

# Zoxide configuration
eval "$(zoxide init zsh)"
alias cd="z"
alias cdd="zi"

# Starship prompt
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"

# Additional zsh plugins
source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "$HOME/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

# ============================================================================
# Aliases
# ============================================================================

# Shell management
alias zshrc="source $HOME/.config/zsh/.zshrc"

# File navigation and listing
alias ls="eza --icons"
alias l="eza --icons"
alias ss="yazi $HOME/LocalStorage/Screenshot"

# Zellij
alias zel=zellij 
alias zell="zel attach lockin"

## Easy Lazygit
alias lg="lazygit"
alias lz="lazygit"

## Easy LazyDocker
alias ld="Lazydocker"

## Easy Bat/Cat
alias cat=bat

## Basic Utils 
alias nv="nvim"
alias cls="clear"

## Cloc Util
alias gcloc='g ls-files | cloc --list-file=-'

# Stuff I never really use but cannot delete either because of http://xkcd.com/530/
alias stfu="osascript -e 'set volume output muted true'"
alias pumpitup="osascript -e 'set volume output volume 100'"
alias moon='osascript -e '\''tell application "Macs Fan Control" to activate'\'''
alias earth='osascript -e '\''tell application id "com.crystalidea.macsfancontrol" to quit'\'' 2>/dev/null'

## Funny Systemctl
alias byebye="sudo shutdown -h now"      # Shutdown
alias zzz="pmset sleepnow"               # Sleep
alias resurrect="sudo shutdown -r now"   # Reboot
alias restart="resurrect"

## File Exploration
alias search="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}' | xargs nvim"

## LLM SLOP
alias nlm='git ls-files -z | grep -zv "^llm.md$" | while IFS= read -r -d "" file; do printf "\n# %s\n\n" "$file"; cat "$file"; printf "\n\n"; done | tee llm.md | pbcopy'

# History management
historyShow() {
  fc -ln 1 | fzf --tac --no-sort | tr -d '\n' | pbcopy
  echo "Copied to clipboard"
}

historyExec() {
  local cmd=$(fc -ln 1 | fzf --tac --no-sort)
  [[ -n "$cmd" ]] && echo "→ $cmd" && eval "$cmd"
}

alias hi="historyShow"
alias hx="historyExec"
# System monitoring
alias df="duf"
alias du="duf"
alias ping="gping"
alias nettest="gping google.com"

# Copy Alias
alias pwdc="pwd | pbcopy"

# AeroSpace window management
aerospace_windows() {
  aerospace list-windows --all | fzf --bind 'enter:execute(bash -c "aerospace focus --window-id {1}")+abort'
}
alias ff="aerospace_windows"

# ============================================================================
# PATH exports
# ============================================================================

# Visual Studio Code
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# ============================================================================
# SSH
# ============================================================================

alias mini="ssh kushvinth@mini-pekka"

# ============================================================================
# Environment variables
# ============================================================================

export HOMEBREW_NO_ENV_HINTS=1
export ANTHROPIC_BASE_URL="http://localhost:8080"
export ANTHROPIC_AUTH_TOKEN="test"
export PATH="/usr/local/sbin:$PATH"

# opencode
export PATH=/Users/MacbookPro/.opencode/bin:$PATH

# Minecraft Java 
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH=$JAVA_HOME/bin:$PATH
export PATH="$HOME/.cargo/bin:$PATH"

# yt-dlp functions
function yt() {
  local link=""
  local output_dir="$HOME/LocalStorage/YT-DLP"

  mkdir -p "$output_dir"

  if [ -n "$1" ] && echo "$1" | grep -qE "^https?://"; then
    link="$1"
    shift
  elif [ -n "$1" ] && [ -f "$1" ]; then
    link="$1"
    shift
  elif pbpaste | grep -qE "^https?://"; then
    link="$(pbpaste)"
  else
    echo "Refusing to download. No link or file provided." >&2
    return 1
  fi

  local args=(
    --format "bestvideo[vcodec^=avc]+bestaudio[acodec^=mp4a]/bestvideo+bestaudio/best"
    ## This is ⬇️⬇️⬇️⬇️ The better format but i will have to use VLC (which doesn't have the best UI)
    # --format "bestvideo+bestaudio/best"
  
    --merge-output-format mp4
    --audio-quality 0
    --embed-thumbnail
    --embed-subs
    --sub-langs "all"
    --output "$output_dir/%(title)s.%(ext)s"
  )

  yt-dlp "${args[@]}" "$link" "$@" || \
  yt-dlp --cookies-from-browser=zen "${args[@]}" "$link" "$@"
  open $HOME/LocalStorage/YT-DLP
}

# Brew path
if [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"

elif [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi