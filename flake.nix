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

    # Only the prebuilt weekly database is wanted here, not the tool: nixpkgs
    # ships nix-index itself, but generating its index locally is a ~15 minute
    # run that is stale again by the next flake update.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The website Carbon serves. Over HTTPS rather than the `ssh://carbon:2222`
    # remote the repo is cloned from day to day: the repository is public, and
    # this way evaluating the flake does not require being on the tailnet.
    #
    # This is also the deploy mechanism. The revision in flake.lock is the
    # revision Carbon runs, so `just deploy-site` is a lock bump and a rebuild,
    # and rolling the site back is rolling back a generation.
    taxborn-com = {
      url = "git+https://git.mischief.town/taxborn/taxborn.com.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The PDS behind pds.mischief.town. Deliberately not following our nixpkgs,
    # unlike every input above: Tranquil is a large Rust tree whose CI pushes
    # finished artifacts to tranquil.cachix.org, built against the pin in its
    # own lock. Following ours would change every derivation hash and rule that
    # cache out permanently. Keeping the pin makes what we evaluate identical to
    # what CI publishes — verified, same store path — so the cache is usable
    # whenever it has actually been populated for the pinned revision.
    tranquil.url = "git+https://tangled.org/tranquil.farm/tranquil-pds";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
