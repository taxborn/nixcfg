{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
      btrfs-helium = ../disko/btrfs-helium.nix;
      # tungsten: SK hynix PC801 1TB + WD Blue SN550 1TB; the 930G cap bounds
      # the raid partition to the smaller drive.
      # btrfs-luks-raid1--tungsten = import ../disko/btrfs-luks-raid1.nix {
      #   nvme0 = "/dev/disk/by-id/nvme-PC801_NVMe_SK_hynix_1TB__SSB6N580011606E0S";
      #   nvme1 = "/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_203040806179";
      #   raidSize = "930G";
      # };

      # uranium: 2x Samsung 980 PRO 2TB (a Patriot P300 512GB and an 850 EVO
      # 250GB are installed but unused).
      btrfs-luks-raid1-uranium = import ../disko/btrfs-luks-raid1.nix {
        nvme0 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900787H";
        nvme1 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900698K";
      };
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
