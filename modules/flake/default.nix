{ self, inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
    };

    homeModules = {
      default = ../home;
    };

    nixosModules = {
      hardware = ../hardware;
      nixos = ../nixos;
      users = ../users;
    };

    nixosConfigurations =
      let modules = self.nixosModules; in inputs.nixpkgs.lib.genAttrs
        [
          # FIXME: uncomment hosts when ready
          "argon"
          # "carbon"
          # "helium"
          # "tungsten"
          # "uranium"
        ]
        (
          host:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [
              ../../hosts/${host}
              inputs.disko.nixosModules.disko
              inputs.home-manager.nixosModules.home-manager

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
