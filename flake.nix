{
  description = "braxton's homelab setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned so `nix flake update` cannot upgrade it. See docs/services.md#pinned-services.
    tranquil-src = {
      url = "git+https://tangled.org/did:plc:jj6ajj6duxnlthwtnob4qyuv?ref=main&rev=ce17e8a4948aa216c6c1056122966a11b8a693c8";
      flake = false;
    };

    # Pinned like tranquil-src. No nixpkgs.follows: its crates are built against its own toolchains.
    tangled.url = "git+https://tangled.org/did:plc:j5hmlfdrwkvtxm7cjmu7j2is?ref=master&rev=21c431c0c48215365980331fea16547f79bdea0b";

    # Pinned like tranquil-src. Piper migrates its schema on startup.
    tealfm-piper = {
      url = "github:teal-fm/piper/8177627d1424712202b2c34719cc89b5f7bad099";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
