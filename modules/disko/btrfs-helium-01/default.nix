# Helium Drive setup (`nvme list`)
# Node                  Generic               SN                   Model                                    Namespace  Usage                      Format           FW Rev
# --------------------- --------------------- -------------------- ---------------------------------------- ---------- -------------------------- ---------------- --------
# /dev/nvme0n1          /dev/ng0n1            230347595111032      SPCC M.2 PCIe SSD                        0x1          2.05  TB /   2.05  TB    512   B +  0 B   VC2S038E

# # References
# FIDO2: https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
# Multi-drive: https://github.com/soulcramer/Wimpy-nix-config/blob/main/nixos/maul/disks.nix
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
