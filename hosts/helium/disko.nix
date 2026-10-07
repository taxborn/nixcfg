# Helium's single 2 TB NVMe. Find the by-id path with `ls -l /dev/disk/by-id`.
{ self, ... }:
let
  nvme0 = "/dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_230347595111032";

  defaultBtrfsOpts = import "${self}/modules/disko/btrfs-opts.nix";
in
{
  disko.devices = {
    disk = {
      root-disk = {
        device = nvme0;
        type = "disk";

        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "/home/.snapshots" = {
                    mountpoint = "/home/.snapshots";
                    mountOptions = defaultBtrfsOpts;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
