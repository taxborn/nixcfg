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

  defaultExtraFormatArgs = [
    "--cipher=aes-xts-plain64"
    "--hash=sha256"
    "--iter-time=1000"
    "--key-size=256"
    "--pbkdf-memory=1048576"
    "--sector-size=4096"
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
              };
            };

            luks-root = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings.allowDiscards = true;
                extraFormatArgs = defaultExtraFormatArgs;
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
  };
}
