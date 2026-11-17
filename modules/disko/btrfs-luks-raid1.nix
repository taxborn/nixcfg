# Workstation layout. See docs/hosts.md#disk-layouts.
{
  nvme0,
  nvme1,
  # Size against the smaller drive minus its ESP.
  raidSize ? "100%",
  games ? null,
  backup ? null,
}:
{
  config,
  lib,
  self,
  ...
}:
let
  fallbackMountPoint = "/boot-fallback";

  defaultBtrfsOpts = import "${self}/modules/disko/btrfs-opts.nix";

  companionBtrfsOpts = [
    "compress=no"
    "discard=async"
    "noatime"
    "nofail"
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

  keyStagingDir = "/tmp/luks";
  keyDir = "/etc/luks";

  companions = lib.filterAttrs (_: device: device != null) { inherit games backup; };

  companionDisk =
    {
      name,
      subvolumes,
      enrollRecovery ? false,
    }:
    {
      device = companions.${name};
      type = "disk";
      content = {
        type = "gpt";
        partitions.${name} = {
          size = "100%";
          content = {
            type = "luks";
            inherit name enrollRecovery;

            # The keyfile lives on the encrypted root, so these unlock in stage 2.
            initrdUnlock = false;

            settings = {
              allowDiscards = true;
              keyFile = "${keyStagingDir}/${name}.key";
            };
            extraFormatArgs = defaultExtraFormatArgs;

            # Reuse an existing key. Minting a new one on a re-run locks out the data.
            preCreateHook = ''
              if [ ! -f ${keyStagingDir}/${name}.key ]; then
                mkdir -p ${keyStagingDir}
                chmod 0700 ${keyStagingDir}
                dd if=/dev/urandom of=${keyStagingDir}/${name}.key bs=512 count=1 status=none
                chmod 0400 ${keyStagingDir}/${name}.key
              fi
            '';

            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              inherit subvolumes;

              postMountHook = ''
                if [ ! -f /mnt${keyDir}/${name}.key ]; then
                  install -D -m 0400 ${keyStagingDir}/${name}.key /mnt${keyDir}/${name}.key
                fi
              '';
            };
          };
        };
      };
    };
in
{
  assertions = [
    {
      assertion = config.boot.lanzaboote.enable;
      message = ''
        The btrfs-luks-raid1 layout puts a fallback ESP on nvme1 at
        ${fallbackMountPoint}, and lanzaboote is the only bootloader here that
        installs to it. Import modules/nixos/workstation on this host, or
        teach modules/disko/btrfs-luks-raid1.nix how to populate that mount
        point for whichever bootloader replaces it.
      '';
    }
  ];

  environment.etc.crypttab = lib.mkIf (companions != { }) {
    text = lib.concatMapStrings (
      name: "${name} ${companions.${name}}-part1 ${keyDir}/${name}.key luks,discard,nofail\n"
    ) (lib.attrNames companions);
  };

  boot = {
    lanzaboote.extraEfiSysMountPoints = [ fallbackMountPoint ];
    swraid.mdadmConf = lib.mkDefault "MAILADDR root";
  };

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
            # Without a second ESP the mirror survives a dead disk that the machine cannot boot from.
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = fallbackMountPoint;
                mountOptions = [
                  "umask=0077"
                  "nofail"
                ];
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
    }
    // lib.optionalAttrs (games != null) {
      games = companionDisk {
        name = "games";

        subvolumes = {
          # One subvolume: Steam installs by rename(), which fails across subvolumes.
          "/games" = {
            mountpoint = "/games";
            mountOptions = companionBtrfsOpts;
          };

          "/compatdata" = {
            mountpoint = "/games/steamapps/compatdata";
            mountOptions = companionBtrfsOpts;
          };

          "/compatdata/.snapshots" = {
            mountpoint = "/games/steamapps/compatdata/.snapshots";
            mountOptions = companionBtrfsOpts;
          };
        };
      };
    }
    // lib.optionalAttrs (backup != null) {
      backup = companionDisk {
        name = "backup";

        # Without a recovery key, losing the root array takes this repository with it.
        enrollRecovery = true;

        subvolumes = {
          # Never snapshot: it would pin every segment borg prune deletes.
          "/borg" = {
            mountpoint = "/mnt/backup";
            mountOptions = companionBtrfsOpts;
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
          settings = {
            allowDiscards = true;
            crypttabExtraOpts = [ "fido2-device=auto" ];
          };
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
