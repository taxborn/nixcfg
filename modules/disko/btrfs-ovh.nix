# Single-disk GPT + btrfs layout shared by Argon and Carbon.
# Keep both boot paths. Disko sees EF02 and adds this disk to
# boot.loader.grub.devices for a BIOS install. efiSupport also installs to the
# 300M ESP, so enabling EFI does not make the 2M BIOS partition redundant.
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
