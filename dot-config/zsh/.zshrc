: "${ZDOTDIR:=$HOME/.config/zsh}"
: "${ZSH:=$HOME/.oh-my-zsh}"
: "${ZSH_CUSTOM:=$ZDOTDIR/assets/custom}"

# Secrets, pulled from macOS Keychain at shell start (never stored in plaintext).
# Add/update with: security add-generic-password -a "$USER" -s <service> -w <value> -U
if command -v security >/dev/null 2>&1; then
  _keychain_env() {
    local var="$1" service="$2" val
    val=$(security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null) || return
    export "$var=$val"
  }
  _keychain_env BORG_PASSPHRASE borg-xteink
  _keychain_env GITHUB_PERSONAL_ACCESS_TOKEN github-personal-access-token
  unset -f _keychain_env
fi

export BORG_REPO=/Users/MacbookPro/LocalStorage/Developer/xtenik/backup

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
# shellcheck disable=SC2296,SC1036
fpath=(${^fpath}(N))

ZSH_THEME=""

# Inline completion menu
zstyle ':completion:*' menu select
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

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

# shellcheck disable=SC2128
fpath=("/etc/profiles/per-user/$USER/share/zsh/site-functions" /run/current-system/sw/share/zsh/site-functions $fpath)
# No compinit here: oh-my-zsh runs it (into $ZSH_COMPDUMP); a second one cost ~0.05 s per shell.

# zsh-autocomplete must load before oh-my-zsh
#[[ -r "$ZSH_CUSTOM/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] &&
#  source "$ZSH_CUSTOM/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

export FZF_BASE="${FZF_BASE:-/run/current-system/sw/share/fzf}"

source "$ZSH/oh-my-zsh.sh"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# nix-darwin would add these via /etc/zshrc, which NOSYSZSHRC skips.
# direnv: per-project .envrc (with nix-direnv for `use flake`).
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
# nix-index: "command not found" → suggests the nixpkgs package (or try `, <cmd>`).
[[ -r /run/current-system/sw/etc/profile.d/command-not-found.sh ]] &&
  source /run/current-system/sw/etc/profile.d/command-not-found.sh

# zsh-syntax-highlighting must load after oh-my-zsh
if [[ -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" ]]; then
  source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
elif [[ -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

source "$ZDOTDIR/.zshalias"

# Clear stale local Anthropic proxy/test overrides from inherited shells.
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
