: "${ZDOTDIR:=$HOME/.config/zsh}"
: "${ZSH:=$HOME/.oh-my-zsh}"
: "${ZSH_CUSTOM:=$ZDOTDIR/assets/custom}"

# Homebrew before compinit so fpath gets a valid site-functions dir (not stale /usr/local).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  # Apple Silicon: drop Intel Homebrew completions dir (often a dangling _brew symlink).
  fpath=(${fpath:#/usr/local/share/zsh/site-functions})
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Dangling completion symlink left by an old Homebrew install.
if [[ -L /usr/local/share/zsh/site-functions/_brew && ! -e /usr/local/share/zsh/site-functions/_brew ]]; then
  command rm -f /usr/local/share/zsh/site-functions/_brew 2>/dev/null
fi

# Drop missing fpath entries (stale HM store links, removed Intel Homebrew completions, etc.).
fpath=(${^fpath}(N))

ZSH_THEME=""

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

fpath=("$ZDOTDIR/completions"(N) $fpath)
fpath=(${^fpath}(N))

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
