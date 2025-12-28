{ self, ... }:
{
  flake = {
    homeModules = {
      default = ../home;
      taxborn = ../../homes/taxborn;
    };
  };
}
