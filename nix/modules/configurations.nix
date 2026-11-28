{
  inputs,
  lib,
  config,
  ...
}:
let
  mkConfigurationsOption =
    kind:
    lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule {
          options.module = lib.mkOption {
            type = lib.types.deferredModule;
            default = { };
            description = "${kind} module for this configuration";
          };
        }
      );
      default = { };
      description = "${kind} system configurations";
    };

  nixosConfigurations = lib.mapAttrs (
    name: cfg:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.overlays = [ config.flake.overlays.default ];
          nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
          networking.hostName = lib.mkDefault name;
        }
        cfg.module
      ];
    }
  ) config.configurations.nixos;

  darwinConfigurations = lib.mapAttrs (
    name: cfg:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs;
        user = "MacbookPro";
        hostname = name;
      };
      modules = [
        {
          nixpkgs.overlays = [ config.flake.overlays.default ];
          nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
          system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        }
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        inputs.nix-index-database.darwinModules.nix-index
        cfg.module
      ];
    }
  ) config.configurations.darwin;

  homeConfigurations = lib.mapAttrs (
    name: cfg:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = cfg.system;
        overlays = [ config.flake.overlays.default ];
        config.allowUnfree = true;
      };
      extraSpecialArgs = {
        inherit inputs;
        user = cfg.user;
      };
      modules = [
        cfg.module
      ];
    }
  ) config.configurations.home;
in
{
  options.configurations = {
    nixos = mkConfigurationsOption "NixOS";
    darwin = mkConfigurationsOption "nix-darwin";
    home = lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule {
          options = {
            user = lib.mkOption {
              type = lib.types.str;
              description = "Target username";
            };
            system = lib.mkOption {
              type = lib.types.str;
              default = "x86_64-linux";
              description = "Target system architecture";
            };
            module = lib.mkOption {
              type = lib.types.deferredModule;
              default = { };
              description = "Home Manager module";
            };
          };
        }
      );
      default = { };
      description = "Standalone Home Manager configurations";
    };
  };

  config.flake = {
    inherit nixosConfigurations darwinConfigurations homeConfigurations;

    checks = {
      # macOS runners can't build the Linux dev guest (no nested virt for a
      # linux-builder), so CI builds the Mac with a stub in place of its boot
      # artefacts; the guest itself is built by the aarch64-linux job
      # (checks.aarch64-linux.dev-guest*, nix/modules/dev/guest.nix).
      aarch64-darwin.MacbookPro =
        (config.flake.darwinConfigurations.MacbookPro.extendModules {
          modules = [
            (
              { pkgs, ... }:
              {
                devvm.guestBootEnv = pkgs.writeText "dev-guest.env" "# CI stub: no guest artefacts\n";
              }
            )
          ];
        }).config.system.build.toplevel;
      aarch64-linux.darwin-eval =
        let
          drv = config.flake.darwinConfigurations.MacbookPro.system;
        in
        (import inputs.nixpkgs { system = "aarch64-linux"; }).runCommand "darwin-eval" { } ''
          echo ${builtins.unsafeDiscardStringContext drv.drvPath} > $out
        '';
      x86_64-linux.ubuntu = config.flake.homeConfigurations.ubuntu.activationPackage;
    };
  };
}
