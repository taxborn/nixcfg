{ self, inputs, ... }:
{
  flake = {
    nixosModules = {
      locale-en-us = ../locale/en-us;
      nixos = ../nixos;
      users = ../users;
    };

    nixosConfigurations =
      let
        modules = self.nixosModules;
      in
      inputs.nixpkgs.lib.genAttrs
        [
          # "carbon"
          # "helium-01"
          "tungsten"
          # "uranium"
        ]
        (
          host:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [
              ../../hosts/${host}
              inputs.agenix.nixosModules.default
              inputs.home-manager.nixosModules.home-manager

              modules.nixos
              modules.users

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
  };
}
