{
  description = "kuestional nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Prebuilt nix-index database: command-not-found + `, <cmd>` (comma).
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Guest for the per-project `dev` microVMs (nixosConfigurations.dev-guest,
    # nix/modules/dev). Only its NixOS modules are used: devctl launches vfkit itself.
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    tap-nextfire = {
      url = "github:NextFire/homebrew-tap";
      flake = false;
    };
  };

  # Dendritic flake-parts setup: every .nix file under ./modules (outside /_*)
  # is automatically imported as a flake-parts module via import-tree.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
