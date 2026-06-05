: "${ZDOTDIR:=$HOME/.config/zsh}"
: "${ZSH:=$HOME/.oh-my-zsh}"
: "${ZSH_CUSTOM:=$ZDOTDIR/assets/custom}"

ZSH_THEME=""

plugins=(
  git
  sudo
  #you-should-use
  starship
  man
  colored-man-pages
  fzf
  forgit
)

fpath=("$ZDOTDIR/completions" $fpath)
autoload -Uz compinit
compinit

# zsh-autocomplete must load before oh-my-zsh
[[ -r "$ZSH_CUSTOM/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] &&
  source "$ZSH_CUSTOM/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

source "$ZSH/oh-my-zsh.sh"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# zsh-syntax-highlighting must load after oh-my-zsh
if [[ -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" ]]; then
  source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
elif [[ -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

source "$ZDOTDIR/.zshalias"

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
