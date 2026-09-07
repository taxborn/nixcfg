{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
      btrfs-luks-raid1 = ../disko/btrfs-luks-raid1.nix;
    };

    homeModules = {
      # Deliberately the same tree as `nixosModules.snippets` below, which is
      # what makes a snippet a snippet: pure data, evaluated in both, so the
      # ssh client config in modules/home and the Forgejo server config in
      # modules/nixos read one port out of one attribute and cannot disagree.
      snippets = inputs.import-tree ../snippets;
      default = inputs.import-tree ../home;
      profile-default = ../../homes/default.nix;
      profile-workstation = ../../homes/workstation.nix;
      profile-server = ../../homes/server.nix;
    };

    nixosModules = {
      snippets = inputs.import-tree ../snippets;
      hardware = inputs.import-tree ../hardware;
      nixos = inputs.import-tree ../nixos;
      users = inputs.import-tree ../users;
    };
  };
}
