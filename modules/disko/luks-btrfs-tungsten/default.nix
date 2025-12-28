{
  config,
  lib,
  ...
}:
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
  options.myDisko.installDrive = lib.mkOption {
    description = "Disk to install NixOS to.";
    default = "/dev/nvme0n1";
    type = lib.types.str;
  };

  config = {
    assertions = [
      {
        assertion = config.myDisko.installDrive != "";
        message = "config.myDisko.installDrive cannot be empty.";
      }
    ];

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
  };
}
