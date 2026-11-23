{ inputs, ... }:
let
  tranquilVersion = "0.8.0-unstable-${inputs.tranquil-src.shortRev}";

  piperVersion = "0.1.1-unstable-${inputs.tealfm-piper.shortRev}";

  frontendRoot = "source/frontend";
in
{
  perSystem =
    { system, pkgs, ... }:
    {
      packages = {
        agenix = inputs.agenix.packages.${system}.default;

        tg = inputs.tg.packages.${system}.tg;

        spindle-nixos-image = inputs.tangled.packages.${system}.spindle-nixos-image;

        catppuccin-lazygit = (import inputs.catppuccin { inherit pkgs; }).packages.lazygit;

        # A local derivation, so the vendor hash fails closed when dependencies change.
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

        tranquil-pds = pkgs.tranquil-pds.overrideAttrs (old: {
          version = tranquilVersion;
          buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
          src = inputs.tranquil-src;

          # Overriding cargoHash does nothing after the fact. Replacing cargoDeps re-vendors.
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            src = inputs.tranquil-src;
            hash = "sha256-MHnKgrT30Wi4B+nlm8i0EVm++zK3Q1lZtExYNP2vsFU=";
          };
        });

        # Two-argument form. previousAttrs would re-evaluate sourceRoot against the new src.
        tranquil-pds-frontend = pkgs.tranquil-pds-frontend.overrideAttrs (
          finalAttrs: _: {
            version = tranquilVersion;
            src = inputs.tranquil-src;
            sourceRoot = frontendRoot;

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
