{ lib, ... }:
let
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
        device = lib.mkDefault "/dev/sda";
        type = "disk";

        content = {
          type = "gpt";
          partitions = {
            # Boot partitions
            boot = {
              name = "boot";
              size = "2M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "300M";
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
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    # 16 GB of RAM + some space
                    swap.swapfile.size = "18G";
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
