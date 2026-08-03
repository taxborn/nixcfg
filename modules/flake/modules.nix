{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
      btrfs-helium = ../disko/btrfs-helium.nix;
      btrfs-luks-raid1-tungsten = import ../disko/btrfs-luks-raid1.nix {
        nvme0 = "/dev/disk/by-id/nvme-PC801_NVMe_SK_hynix_1TB__SSB6N580011606E0S";
        nvme1 = "/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_203040806179";
        raidSize = "920G";
      };
      btrfs-luks-raid1-uranium = import ../disko/btrfs-luks-raid1.nix {
        nvme0 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900787H";
        nvme1 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900698K";
        games = "/dev/disk/by-id/nvme-Patriot_M.2_P300_512GB_P300PBBB240118013691";
        backup = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21NNXAG817864H";
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
