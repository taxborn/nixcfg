{
  flake = {
    homeModules = {
      default = ../home;
      profile-default = ../../homes/default.nix;
      profile-workstation = ../../homes/workstation.nix;
    };
  };
}
