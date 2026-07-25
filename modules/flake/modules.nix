{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
    };

    homeModules = {
      default = inputs.import-tree ../home;
    };

    nixosModules = {
      hardware = inputs.import-tree ../hardware;
      nixos = inputs.import-tree ../nixos;
      users = inputs.import-tree ../users;
    };
  };
}
