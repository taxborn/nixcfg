{ inputs, ... }:
let
  # Tranquil tracks `main`, so the tag-derived version nixpkgs sets no longer
  # identifies what is being built -- upstream has not bumped Cargo.toml since
  # v0.6.6, and two different commits would otherwise produce the same version
  # string. The short rev is what makes a `nixos-rebuild` diff legible.
  tranquilVersion = "0.6.6-unstable-${inputs.tranquil-src.shortRev}";

  # Same problem, same shape. `github:teal-fm/piper` names no ref, so the input
  # tracks the default branch while upstream's package.nix still says 0.0.11:
  # every commit since built as that one version, and a `nixos-rebuild` diff
  # showed nothing when piper moved.
  piperVersion = "0.0.11-unstable-${inputs.tealfm-piper.shortRev}";

  # A flake input is an attrset of `outPath`, `rev`, `narHash` and friends --
  # it has no `name`, which the nixpkgs frontend derivation reaches for in its
  # own `sourceRoot`. Nix names a git checkout's store path `source`, and
  # stdenv strips the hash prefix when it unpacks, so this is that expression
  # resolved by hand rather than a value picked out of the air.
  frontendRoot = "source/frontend";
in
{
  # Re-exported so the NixOS module can reach it as
  # `self.packages.<system>.braxton-is`. Every module in this repo takes `self`
  # and none take `inputs` — `modules/flake/hosts.nix` passes only the former in
  # `specialArgs` — and going through here keeps that true rather than widening
  # the argument every module is written against for the sake of one service.
  #
  # It also means `nix build .#braxton-is` works from this repo, which is the
  # smoke test worth running before a deploy: it builds exactly what the unit on
  # Carbon will execute.
  perSystem =
    { system, pkgs, ... }:
    {
      packages = {
        braxton-is = inputs.braxton-is.packages.${system}.default;
        agenix = inputs.agenix.packages.${system}.default;

        # The upstream lazygit theme, which `modules/home/programs/git.nix`
        # rewrites at build time. catppuccin/nix is not a flake that exposes
        # this under `packages`, so it is imported against nixpkgs here.
        catppuccin-lazygit = (import inputs.catppuccin { inherit pkgs; }).packages.lazygit;

        # Build the flake input's checkout rather than the upstream
        # `tealfm-piper` output, which pins an older commit in package.nix.
        # That keeps this package at the revision locked in flake.lock.
        #
        # Upstream's Go module vendor hash applies to that older source only.
        # Keep a local derivation so updates calculate their own fixed-output
        # vendor dependency set and fail closed when it changes.
        tealfm-piper = pkgs.buildGoModule {
          pname = "tealfm-piper";
          version = piperVersion;
          src = inputs.tealfm-piper;
          vendorHash = "sha256-0CAKzBBARoHSqDv34Xx3Yek6r33Exhrhvn+FzGlby14=";

          nativeBuildInputs = [ pkgs.tailwindcss_4 ];
          env.CGO_ENABLED = 1;
          subPackages = [ "cmd" ];

          postBuild = ''
            cp -r ./pages/templates $out/
            cp -r ./pages/static $out/
            tailwindcss -i $out/static/base.css -o $out/static/main.css -m
          '';

          postInstall = ''
            mv $out/bin/cmd $out/bin/piper
          '';
        };

        # The server and the frontend are two derivations over one source tree
        # and have to move together: the server serves the frontend out of
        # `settings.frontend.dir`, so a skew between them is a broken web UI at
        # runtime rather than a failure at build time. Both take `src` from the
        # same input for that reason.
        tranquil-pds = pkgs.tranquil-pds.overrideAttrs (_: {
          version = tranquilVersion;
          src = inputs.tranquil-src;

          # Overriding `cargoHash` here would do nothing. buildRustPackage
          # reads it once, when it builds the derivation, to construct
          # `cargoDeps` — by the time overrideAttrs runs, that fixed-output
          # derivation is already pinned to the release tag's dependency set.
          # Replacing `cargoDeps` outright is what actually re-vendors.
          #
          # fetchCargoVendor rather than `cargoLock.lockFile` because Tranquil
          # pulls 13 crates straight from git, and the latter wants an
          # `outputHashes` entry for every one of them.
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            src = inputs.tranquil-src;
            hash = "sha256-fjT0cAt7lPD0O2PGNT604dRIczerKjExJvU/L3Yul3c=";
          };
        });

        # Two-argument overrideAttrs: the single-argument form binds
        # `previousAttrs`, and inheriting `sourceRoot` from that pulls the
        # original `"${finalAttrs.src.name}/frontend"` expression back in --
        # which then evaluates against the new `src` and fails on the missing
        # attribute. `finalAttrs` here is the real fixpoint.
        tranquil-pds-frontend = pkgs.tranquil-pds-frontend.overrideAttrs (
          finalAttrs: _: {
            version = tranquilVersion;
            src = inputs.tranquil-src;
            sourceRoot = frontendRoot;

            # Same reasoning as cargoDeps above: the pnpm store is a
            # fixed-output derivation built from the old `src`, so it has to be
            # rebuilt rather than have its hash edited.
            pnpmDeps = pkgs.fetchPnpmDeps {
              inherit (finalAttrs)
                pname
                version
                src
                sourceRoot
                ;
              inherit (pkgs) pnpm;
              fetcherVersion = 4;
              hash = "sha256-+P4UUkZKQJVfGbDFKR0gRMU+wYK9K7NBYo1s/ebRK9I=";
            };
          }
        );
      };
    };
}
