{
  description = "kuestional nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Prebuilt nix-index database: command-not-found + `, <cmd>` (comma).
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Homebrew taps, pinned like any other input (nix-homebrew.mutableTaps = false).
    # `nix flake update` bumps them; `darwin-rebuild --rollback` undoes a bad bump.
    homebrew-core = {
      url = "github:Homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:Homebrew/homebrew-cask";
      flake = false;
    };
    tap-felixkratz = {
      url = "github:FelixKratz/homebrew-formulae";
      flake = false;
    };
    tap-asmvik = {
      url = "github:asmvik/homebrew-formulae";
      flake = false;
    };
    tap-mikescher = {
      url = "github:mikescher/homebrew-tap";
      flake = false;
    };
    tap-gromgit-fuse = {
      url = "github:gromgit/homebrew-fuse";
      flake = false;
    };
    tap-nikitabobko = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    tap-mediosz = {
      url = "github:mediosz/homebrew-tap";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nix-homebrew,
      home-manager,
      nix-index-database,
      ...
    }:
    let
      lib = nixpkgs.lib;
      system = "aarch64-darwin";
      paths = import ./lib/paths.nix { inherit self; };
      link-tree = import ./lib/link-tree.nix { inherit lib; };

      # One entry per machine; each needs hosts/<hostname>.nix.
      hosts = {
        MacbookPro = {
          user = "MacbookPro";
        };
      };

      mkDarwin =
        hostname:
        { user }:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit
              inputs
              hostname
              user
              paths
              link-tree
              ;
          };
          modules = [
            { nixpkgs.overlays = [ self.overlays.default ]; }
            ./hosts/${hostname}.nix
            ./modules/darwin
            home-manager.darwinModules.home-manager
            # `user` comes from specialArgs (not this function's argument) so
            # `extendModules { specialArgs.user = ...; }` changes it everywhere;
            # CI uses that to switch this config as the runner's user.
            (
              { user, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "hm-bak";
                home-manager.extraSpecialArgs = {
                  inherit inputs user;
                };
                home-manager.users.${user} = import ./modules/home;
              }
            )
            nix-homebrew.darwinModules.nix-homebrew
            nix-index-database.darwinModules.nix-index
            {
              system.configurationRevision = self.rev or self.dirtyRev or null;
            }
          ];
        };

      darwinConfigurations = lib.mapAttrs mkDarwin hosts;

      # The system's own nixpkgs instance (overlay + allowUnfree applied), reused
      # for flake outputs so there is only one package set.
      pkgs = darwinConfigurations.MacbookPro.pkgs;
    in
    {
      inherit darwinConfigurations;

      overlays.default = final: _prev: import ./packages { pkgs = final; };

      # treefmt wrapper around nixfmt (`nix fmt` on a directory with plain
      # nixfmt is deprecated). CI runs `nix fmt -- --ci`.
      formatter.${system} = pkgs.nixfmt-tree;
      packages.${system} = import ./packages { inherit pkgs; };
    };
}
