# Helium's single 2 TB NVMe. Find the by-id path with `ls -l /dev/disk/by-id`.
let
  nvme0 = "/dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_230347595111032";

  defaultBtrfsOpts = [
    "compress=zstd:1"
    "discard=async"
    "noatime"
    "rw"
    "space_cache=v2"
    "ssd"
  ];
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
