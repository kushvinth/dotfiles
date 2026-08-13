{
  description = "kuestional nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      paths = import ./lib/paths.nix { inherit self; };
      link-tree = import ./lib/link-tree.nix { inherit lib; };
    in
    {
      darwinConfigurations.MacbookPro = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit self paths link-tree;
        };
        modules = [
          ./hosts/MacbookPro.nix
          ./modules/darwin
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = {
              inherit paths link-tree;
            };
            home-manager.users.MacbookPro = import ./modules/home;
          }
          nix-homebrew.darwinModules.nix-homebrew
          {
            system.configurationRevision = self.rev or self.dirtyRev or null;
          }
        ];
      };
    };
}
