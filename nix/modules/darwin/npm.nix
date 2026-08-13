{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    typescript
    eslint
    prettier
    nodejs
  ];

  system.activationScripts.postActivation.text = ''
    if ! command -v gnhf &> /dev/null; then
      echo "Installing gnhf..."
      npm install -g gnhf
    fi
  '';
}
