# Tungsten Drive setup (`nvme list`)
# Node                  Generic               SN                   Model                                    Namespace  Usage                      Format           FW Rev
# --------------------- --------------------- -------------------- ---------------------------------------- ---------- -------------------------- ---------------- --------
# /dev/nvme0n1          /dev/ng0n1            203040806179         WDC WDS100T2B0C-00PXH0                   0x1          1.00  TB /   1.00  TB    512   B +  0 B   211070WD
# /dev/nvme1n1          /dev/ng1n1               SSB6N580011606E0S PC801 NVMe SK hynix 1TB                  0x1          1.02  TB /   1.02  TB    512   B +  0 B   51002141
#
# # References
# FIDO2: https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
# Multi-drive: https://github.com/soulcramer/Wimpy-nix-config/blob/main/nixos/maul/disks.nix
let
  nvme0 = "/dev/disk/by-id/nvme-PC801_NVMe_SK_hynix_1TB__SSB6N580011606E0S";
  nvme1 = "/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_203040806179";

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
in {
  disko.devices = {
    disk = {
      root-disk = {
        device = nvme0;
        type = "disk";

        content = {
          type = "gpt";
          partitions = {
            # Boot partition
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks-root = {
              size =  "100%";
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
                      # 32 GB of RAM + some space
                      swap.swapfile.size = "34G";
                    };
                  };
                };
              };
            };
          };
        };
      };

      home-disk = {
        device = nvme1;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            luks-home = {
              size =  "100%";
              content = {
                type = "luks";
                name = "crypthome";
                settings.allowDiscards = true;
                extraFormatArgs = defaultExtraFormatArgs;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "/home" = {
                      mountpoint = "/home";
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
  };
}
