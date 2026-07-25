{ inputs, ... }:

# Each tree is walked recursively by import-tree, so adding a module is just
# dropping a .nix file into the right directory. Files/dirs whose name starts
# with an underscore are skipped.
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
