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
      nixos = ../nixos;
      users = ../users;
    };
  };
}
