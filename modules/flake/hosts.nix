{ self, inputs, ... }:

{
  flake.nixosConfigurations =
    let
      modules = self.nixosModules;
    in
    inputs.nixpkgs.lib.genAttrs
      [
        # FIXME: uncomment hosts when ready
        "argon"
        "carbon"
        "helium"
        # "tungsten"
        "uranium"
      ]
      (
        host:
        inputs.nixpkgs.lib.nixosSystem {
          modules = [
            ../../hosts/${host}
            inputs.agenix.nixosModules.default
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.lanzaboote.nixosModules.lanzaboote

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
              };

              nixpkgs.config.allowUnfree = true;
            }
          ];

          specialArgs = { inherit self; };
        }
      );
}
