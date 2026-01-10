# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

# Plugins
plugins=(
  git
  sudo
  you-should-use
  starship
  man
  colored-man-pages
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

 
## Funny Systemctl
alias byebye="sudo shutdown -h now"      # Shutdown
alias zzz="pmset sleepnow"               # Sleep
alias resurrect="sudo shutdown -r now"   # Reboot
alias restart="resurrect"

## File Exploration
alias search="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}' | xargs nvim"

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
alias ping="gping"
alias nettest="gping google.com"

# Copy Alias
alias pwdc="pwd | pbcopy"

# n8n configuration
export PATH="$PATH:$(npm bin -g)"
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
export N8N_RUNNERS_ENABLED=true

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
