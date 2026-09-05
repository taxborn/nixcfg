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

    # The website Carbon serves. The `forgejo:` SSH alias clones this same
    # repository day to day. The URL here is HTTPS instead, because the
    # repository is public and evaluating the flake should not require being on
    # the tailnet.
    #
    # This is also the deploy mechanism. The revision in flake.lock is the
    # revision Carbon runs, so `just deploy-site` is a lock bump and a rebuild,
    # and rolling the site back is rolling back a generation.
    braxton-is = {
      url = "git+https://code.biscuits.at/braxton/braxton.is.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tranquil, tracking `main` instead of the tagged release nixpkgs carries.
    # `flake = false` because upstream ships no flake.nix. It is a bare source
    # tree that modules/flake/packages.nix hands to the nixpkgs derivations as
    # `src`.
    #
    # Same deploy mechanism as braxton-is above. The revision in flake.lock is
    # the revision Argon runs, so `nix flake update tranquil-src` is the upgrade
    # and rolling back is rolling back the lock. The asymmetry with the site is
    # the part to remember: a rollback here does not undo database migrations,
    # and Tranquil has none in the reverse direction. Take a dump first.
    #
    # tangled.org redirects to a knot host (knot1.tangled.sh) on fetch. git
    # follows it; worth knowing when a fetch fails for reasons that look like
    # DNS.
    tranquil-src = {
      url = "git+https://tangled.org/did:plc:jj6ajj6duxnlthwtnob4qyuv?ref=main";
      flake = false;
    };

    tealfm-piper = {
      url = "github:teal-fm/piper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
