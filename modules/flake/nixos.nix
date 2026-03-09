{ self, inputs, ... }:
{
  flake = {
    diskoConfigurations = {
      btrfs-argon = ../disko/btrfs-argon;
      btrfs-carbon = ../disko/btrfs-carbon;
      btrfs-helium-01 = ../disko/btrfs-helium-01;
      luks-btrfs-tungsten = ../disko/luks-btrfs-tungsten;
      luks-btrfs-uranium = ../disko/luks-btrfs-uranium;
    };

    nixosModules = {
      hardware = ../hardware;
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
          "argon"
          "carbon"
          "helium-01"
          "tungsten"
          "uranium"
        ]
        (
          host:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [
              ../../hosts/${host}
              inputs.agenix.nixosModules.default
              inputs.copyparty.nixosModules.default
              inputs.disko.nixosModules.disko
              inputs.home-manager.nixosModules.home-manager
              inputs.snippets.nixosModules.snippets
              inputs.lanzaboote.nixosModules.lanzaboote

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
                nixpkgs.overlays = [
                  inputs.copyparty.overlays.default
                  (final: prev: {
                    dwlb = final.callPackage ../../packages/dwlb { };
                    dwl = final.callPackage ../../packages/dwl {
                      src = inputs.dwl-src;
                    };
                  })
                ];
              }
            ];

            specialArgs = { inherit self; };
          }
        );
  };
}
