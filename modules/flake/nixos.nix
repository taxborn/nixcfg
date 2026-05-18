{ self, inputs, ... }:
{
  flake = {
    diskoConfigurations = {
      luks-btrfs-tungsten = ../disko/luks-btrfs-tungsten;
      luks-btrfs-uranium = ../disko/luks-btrfs-uranium;
    };

    nixosModules = {
      hardware = ../hardware;
      nixos = ../nixos;
      users = ../users;
    };

    nixosConfigurations =
      let
        modules = self.nixosModules;
      in
      inputs.nixpkgs.lib.genAttrs
        [
          "tungsten"
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
              ../snippets

              modules.hardware
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
