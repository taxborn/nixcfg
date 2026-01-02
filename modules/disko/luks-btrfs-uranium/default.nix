# Uranium Drive setup (`nvme list`)
# Node                  Generic               SN                   Model                                    Namespace  Usage                      Format           FW Rev
# --------------------- --------------------- -------------------- ---------------------------------------- ---------- -------------------------- ---------------- --------
# /dev/nvme0n1          /dev/ng0n1            S76ENL0X900787H      Samsung SSD 980 PRO 2TB                  0x1        244.43  GB /   2.00  TB    512   B +  0 B   5B2QGXA7
# /dev/nvme1n1          /dev/ng1n1            S76ENL0X900698K      Samsung SSD 980 PRO 2TB                  0x1        592.59  GB /   2.00  TB    512   B +  0 B   5B2QGXA7
# /dev/nvme2n1          /dev/ng2n1            P300PBBB240118013691 Patriot M.2 P300 512GB                   0x1        512.11  GB / 512.11  GB    512   B +  0 B   W0505A3
#
# # References
# FIDO2: https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
# Multi-drive: https://github.com/soulcramer/Wimpy-nix-config/blob/main/nixos/maul/disks.nix
let
  nvme0 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900787H";
  nvme1 = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900698K";
  # leaving these unused for now
  _nvme2 = "/dev/disk/by-id/nvme-Patriot_M.2_P300_512GB_P300PBBB240118013691";
  _ssd0 = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21NNXAG817864H";

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
        device = nvme0;
        type = "disk";

        content = {
          type = "gpt";
          partitions = {
            # Boot partition
            ESP = {
              # Oversize, but I'd rather have too much here.
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks-root = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings.allowDiscards = true;
                extraFormatArgs = defaultExtraFormatArgs;
                postCreateHook = ''
                  sudo systemd-cryptenroll ${nvme0}-part2 --fido2-device=auto
                '';
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
              size = "100%";
              content = {
                type = "luks";
                name = "crypthome";
                settings.allowDiscards = true;
                extraFormatArgs = defaultExtraFormatArgs;
                postCreateHook = ''
                  sudo systemd-cryptenroll ${nvme1}-part1 --fido2-device=auto
                '';
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
