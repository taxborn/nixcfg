{ inputs, ... }:

{
  flake = {
    diskoConfigurations = {
      btrfs-ovh = ../disko/btrfs-ovh.nix;
      btrfs-helium = ../disko/btrfs-helium.nix;
      # tungsten: SK hynix PC801 1TB + WD Blue SN550 1TB.
      #
      # The cap has to leave room for *both* ESPs, not just nvme0's. A nominal
      # 1TB drive is 931.5 GiB; nvme1 spends 4 GiB of that on the fallback ESP
      # and gives the rest to the array, so its member is ~927.5 GiB and the cap
      # has to sit below that or it is not bounding anything. It was 930G, which
      # is above nvme1's member and — if the PC801 is also a nominal 1TB rather
      # than one of the 1024 GB OEM parts — more than nvme0 can even allocate
      # alongside its own 4 GiB ESP, so `disko` would have failed outright.
      #
      # 920G leaves headroom under both. Confirm with `lsblk -b -d` on the
      # hardware before formatting; mdraid mirrors at the smaller member either
      # way, so erring low costs a few GiB and erring high costs the install.
      btrfs-luks-raid1-tungsten = import ../disko/btrfs-luks-raid1.nix {
        nvme0 = "/dev/disk/by-id/nvme-PC801_NVMe_SK_hynix_1TB__SSB6N580011606E0S";
        nvme1 = "/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_203040806179";
        raidSize = "920G";
      };

      # uranium: 2x Samsung 980 PRO 2TB mirrored, plus two companions off the
      # mirror. The P300 is a Gen3 DRAM-less drive whose weakness is sustained
      # writes, which for a Steam library only shows up while downloading —
      # network-bound anyway. The 850 EVO is a 2014-era SATA drive, but its NAND
      # is only ~7% worn and every failure counter reads zero, which is plenty
      # for nightly borg incrementals over a working set of ~50G.
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
