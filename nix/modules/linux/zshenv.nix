# Linux-specific user configuration: bootstrap ZDOTDIR in ~/.zshenv
{ ... }:
{
  flake.modules.homeManager.linuxZshenv = {
    # On Linux, /etc/zshenv does not set ZDOTDIR, so zsh defaults to reading ~/.zshenv.
    # This bootstraps ZDOTDIR to point at ~/.config/zsh and sources ~/.config/zsh/.zshenv.
    home.file.".zshenv".text = ''
      export ZDOTDIR="$HOME/.config/zsh"
      [[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
    '';
  };
}
