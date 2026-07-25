{ self, inputs, ... }:

{
  flake = {
    homeModules = {
      default = ../home;
      taxborn = ../../homes/taxborn;
    };

    nixosModules = {
      nixos = ../nixos;
      users = ../users;
    };
  };
}
