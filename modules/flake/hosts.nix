{ self, inputs, ... }:

{
  flake.nixosConfigurations =
    inputs.nixpkgs.lib.genAttrs (builtins.attrNames (import ../../homelab.nix).hosts)
      (
        host:
        inputs.nixpkgs.lib.nixosSystem {
          modules = [
            ../../hosts/${host}
            inputs.agenix.nixosModules.default
            inputs.catppuccin.nixosModules.catppuccin
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.tealfm-piper.nixosModules.default
            inputs.tangled.nixosModules.knot-rs
            inputs.tangled.nixosModules.spindle

            ../nixos

            ../options.nix

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit self; };
                backupFileExtension = "backup";
                sharedModules = [
                  inputs.catppuccin.homeModules.catppuccin
                ];
              };

              nixpkgs.config.allowUnfree = true;
            }
          ];

          # `self` and nothing else. Every module in the tree is written
          # against that one argument, so a package built from an input is
          # re-exported through
          # modules/flake/packages.nix and reached as
          # `self.packages.<system>.<name>`. Widening this for one service
          # would make `inputs` fair game everywhere.
          specialArgs = { inherit self; };
        }
      );
}
