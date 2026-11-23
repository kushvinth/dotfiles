{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
  mkHomeConfig = user: {
    inherit user;
    system = "x86_64-linux";
    module = {
      imports = [ homeManager.linux ];
      home = {
        username = user;
        homeDirectory = "/home/${user}";
        stateVersion = "24.11";
      };
    };
  };
in
{
  configurations.home = {
    kushvinth = mkHomeConfig "kushvinth";
    ubuntu = mkHomeConfig "ubuntu";
  };
}
