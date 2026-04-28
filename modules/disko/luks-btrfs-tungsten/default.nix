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
              size = "100%";
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
            };
          };
        };
      };
    };
  };
}
