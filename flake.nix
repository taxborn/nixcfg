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
      url = "git+https://tangled.org/did:plc:jj6ajj6duxnlthwtnob4qyuv?ref=main&rev=41b458b5a31127b8ec9481c15156006d39b32d04";
      flake = false;
    };

    # Pinned like tranquil-src. No nixpkgs.follows: its crates are built against its own toolchains.
    tangled.url = "git+https://tangled.org/did:plc:j5hmlfdrwkvtxm7cjmu7j2is?ref=master&rev=af4f4d69adfc252b6a06cf3394e37ddf6eb4a4e2";

    # Pinned like tranquil-src. Piper migrates its schema on startup.
    tealfm-piper = {
      url = "github:teal-fm/piper/edf0963e5db13115d836c21144f02c0dc051ff5b";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned like tranquil-src. Pre-alpha, and the daemon rewrites its own settings files.
    albedo.url = "git+https://tangled.org/did:plc:l7hhzcbqqvpcquau5waryzdu?ref=main&rev=303840f71658a259458e590dde49c05261473556";

    # Pinned like tranquil-src. The Tangled CLI, built with its own nixpkgs.
    tg.url = "git+https://tangled.org/aly.codes/tg?ref=master&rev=9e37dcfee7baf146cfbdc99ca19c29a3aa1e9936";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
