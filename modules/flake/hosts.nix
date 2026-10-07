{ self, inputs, ... }:

{
  flake.nixosConfigurations =
    let
      modules = self.nixosModules;
    in
    inputs.nixpkgs.lib.genAttrs
      [
        # One of three rosters that have to agree. This one decides what gets
        # built; secrets/secrets.nix decides who may decrypt what, and
        # mySnippets.tailnet.tailscaleIPs decides who is backed up. A host
        # listed only here builds and then fails agenix activation on the first
        # secret it is not a recipient of.
        "argon"
        "carbon"
        "helium"
        "tungsten"
        "uranium"
      ]
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

            modules.hardware
            modules.nixos
            modules.users
            modules.snippets

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit self; };
                backupFileExtension = "backup";
                sharedModules = [
                  inputs.catppuccin.homeModules.catppuccin
                  inputs.nix-index-database.homeModules.nix-index
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
