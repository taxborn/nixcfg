{
  flake = {
    homeModules = {
      default = ../home;
      profile-default = ../../homes/profiles/default.nix;
      profile-server = ../../homes/profiles/server.nix;
      profile-workstation = ../../homes/profiles/workstation.nix;
    };
  };
}
