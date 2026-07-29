{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
      btrfs-helium = ../disko/btrfs-helium.nix;
    };

    homeModules = {
      snippets = inputs.import-tree ../snippets;
      default = inputs.import-tree ../home;
      profile-default = ../../homes/default.nix;
      profile-workstation = ../../homes/workstation.nix;
    };

    nixosModules = {
      snippets = inputs.import-tree ../snippets;
      hardware = inputs.import-tree ../hardware;
      nixos = inputs.import-tree ../nixos;
      users = inputs.import-tree ../users;
    };
  };
}
