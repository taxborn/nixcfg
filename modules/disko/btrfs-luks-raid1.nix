# Workstation layout: ESP on the first disk, mdraid RAID1 across both disks,
# LUKS (FIDO2-enrolled at provisioning) on the array, btrfs on top. Called with
# per-host drive paths from modules/flake (diskoConfigurations).
#
# References
# FIDO2: https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
# Multi-drive: https://github.com/soulcramer/Wimpy-nix-config/blob/main/nixos/maul/disks.nix
{
  nvme0,
  nvme1,
  # Caps the raid partition on the first disk so mismatched drive sizes still
  # mirror cleanly (e.g. "930G").
  raidSize ? "100%",
}:
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
      nvme0 = {
        device = nvme0;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            raid = {
              size = raidSize;
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };

      nvme1 = {
        device = nvme1;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            raid = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };
    };

    mdadm = {
      data = {
        type = "mdadm";
        level = 1;
        content = {
          type = "luks";
          name = "cryptroot";
          settings.allowDiscards = true;
          extraFormatArgs = defaultExtraFormatArgs;
          postCreateHook = ''
            sudo systemd-cryptenroll /dev/md/data --fido2-device=auto
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
}
