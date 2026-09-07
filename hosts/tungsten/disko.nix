{ self, ... }:
{
  imports = [
    (import self.diskoConfigurations.btrfs-luks-raid1 {
      nvme0 = "/dev/disk/by-id/nvme-PC801_NVMe_SK_hynix_1TB__SSB6N580011606E0S";
      nvme1 = "/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_203040806179";
      raidSize = "920G";
    })
  ];
}
