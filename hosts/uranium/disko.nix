{ self, ... }:
{
  imports = [
    (import self.diskoConfigurations.btrfs-luks-raid1 {
      nvme0 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900787H";
      nvme1 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900698K";
      games = "/dev/disk/by-id/nvme-Patriot_M.2_P300_512GB_P300PBBB240118013691";
      backup = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21NNXAG817864H";
    })
  ];
}
