{ self, inputs, ... }:

{
  flake = {
    homeModules = {
      default = ../home;
    };

    nixosModules = {
      nixos = ../nixos;
      users = ../users;
    };
  };
}
