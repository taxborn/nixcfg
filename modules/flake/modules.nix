{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
    };

    homeModules = {
      default = inputs.import-tree ../home;
      profile-default = ../../homes/default.nix;
      profile-workstation = ../../homes/workstation.nix;
    };

    nixosModules = {
      hardware = inputs.import-tree ../hardware;
      nixos = inputs.import-tree ../nixos;
      users = inputs.import-tree ../users;
      snippets = inputs.import-tree ../snippets;
    };
  };
}
