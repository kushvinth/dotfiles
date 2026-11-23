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
    # Guest module for the `dev` VM (nixosConfigurations.dev-vm): Lima's init
    # and guest agent for NixOS. Pinned to the release whose image we boot.
    nixos-lima = {
      url = "github:nixos-lima/nixos-lima/e0e086f24b6b8b3d062ca3a1dce1655eb681c237"; # v0.2.2
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs";
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
