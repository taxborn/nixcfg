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

    # Tranquil, at a pinned commit of `main` instead of the tagged release
    # nixpkgs carries. `flake = false` because upstream ships no flake.nix. It
    # is a bare source tree that modules/flake/packages.nix hands to the
    # nixpkgs derivations as `src`.
    #
    # The `rev` below is the revision Argon runs. It is pinned here, not left
    # to the lock, because a bare `nix flake update` moves every unpinned
    # input. Five of six routine lock updates carried a new Tranquil with
    # them, and the vendor hashes in packages.nix only fail when dependencies
    # change, so a source-only upgrade built without a word. Upgrading is
    # editing the `rev` and running `nix flake lock`. Rolling back is putting
    # the old one back. The asymmetry with the site is the part to remember: a
    # rollback here does not undo database migrations, and Tranquil has none
    # in the reverse direction. Take a dump first.
    #
    # tangled.org redirects to a knot host (knot1.tangled.sh) on fetch. git
    # follows it; worth knowing when a fetch fails for reasons that look like
    # DNS.
    tranquil-src = {
      url = "git+https://tangled.org/did:plc:jj6ajj6duxnlthwtnob4qyuv?ref=main&rev=b5a7bf4ea762ccefbc68b9b31a245cbc7b7bd556";
      flake = false;
    };

    # Tangled's knot (git hosting) and spindle (CI), as upstream's NixOS
    # modules. No `nixpkgs.follows`: the flake pins its own nixpkgs release and
    # Rust and Go toolchains, and the knot's crate set is generated against
    # them, so following ours trades a second nixpkgs in the closure for an
    # untested build. Same knot redirect as `tranquil-src` above.
    #
    # Pinned for the same reason as `tranquil-src`. The knot holds its master
    # key and the spindle runs CI as root, so neither should change because
    # nixpkgs did. Upgrade by editing the `rev`.
    tangled.url = "git+https://tangled.org/did:plc:j5hmlfdrwkvtxm7cjmu7j2is?ref=master&rev=21c431c0c48215365980331fea16547f79bdea0b";

    # Pinned like the two above. Piper alters its SQLite schema on startup, so
    # an upgrade is also a migration. Upgrade by editing the revision.
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
