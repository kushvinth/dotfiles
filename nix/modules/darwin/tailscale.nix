{
  flake.modules.darwin.tailscale =
    { pkgs, ... }:
    {
      services.tailscale.enable = true;
      # Explicitly add the CLI to system packages if not automatically linked
      environment.systemPackages = [ pkgs.tailscale ];
    };
}
