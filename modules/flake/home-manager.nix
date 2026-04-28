{
  flake = {
    homeModules = {
      default = ../home;
      profile-default = ../../homes/profiles/default.nix;
      profile-workstation = ../../homes/profiles/workstation.nix;
    };
  };
}
