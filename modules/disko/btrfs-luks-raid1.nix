# Workstation layout: ESP on the first disk, mdraid RAID1 across both disks,
# LUKS (FIDO2-enrolled at provisioning) on the array, btrfs on top. Called with
# per-host drive paths from modules/flake (diskoConfigurations).
#
# Two optional companion drives sit outside the mirror, each on its own LUKS
# volume: `games` for a Steam library and `backup` for a local borg repository.
# What lands on them is either reproducible (game installs) or already redundant
# (archives that also live on helium and rsync.net), so neither earns a place on
# the mirror — and keeping them off it also keeps them out of the root array's
# snapshot and backup scope, which is the point.
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
  # Optional single-disk companions, as by-id paths. Null on hosts without them.
  games ? null,
  backup ? null,
}:
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

  # The companions take the same options minus compression, plus `nofail`.
  # Everything that lands on them arrives compressed already — game assets ship
  # that way, and borg applies its own zstd before the bytes reach the
  # filesystem — so btrfs compression is CPU spent to save nothing. `nofail`
  # matters more: neither drive is on the path to a login prompt, and the games
  # drive is the cheapest and least proven device in the machine.
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

  # Companion keyfiles are generated into the installer at `keyStagingDir` and
  # come to rest at `keyDir` on the encrypted root.
  keyStagingDir = "/tmp/luks";
  keyDir = "/etc/luks";

  # disko's default rootMountPoint, which the postMountHook writes through.
  rootMountPoint = "/mnt";

  companions = lib.filterAttrs (_: device: device != null) { inherit games backup; };

  # GPT, one partition, LUKS, btrfs. Shared by both companions, since the only
  # things that differ between them are the subvolume layout and whether losing
  # the root array is allowed to take the volume with it.
  companionDisk =
    {
      name,
      subvolumes,
      # Enrolls a high-entropy recovery passphrase in a second keyslot and prints
      # it as a QR code during installation, making the volume openable without
      # the keyfile. Set this wherever the volume has to outlive the root array;
      # leave it off where the contents are disposable and the extra install
      # step is not worth it.
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

            # These cannot be unlocked from the initrd: their keyfile lives on
            # the encrypted root, which at initrd time is the volume still being
            # unlocked. /etc/crypttab (below) opens them in stage 2 instead,
            # once / is mounted and the key is actually readable.
            initrdUnlock = false;

            settings = {
              allowDiscards = true;
              keyFile = "${keyStagingDir}/${name}.key";
            };
            extraFormatArgs = defaultExtraFormatArgs;

            # Generate the key when the installer does not already have one, so
            # a bare `disko` run is self-contained. Guarded rather than
            # unconditional: re-running against an already-formatted volume has
            # to reuse the key it was created with, not mint a fresh one and
            # lock itself out of the data.
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

              # Copy the staged key into the installed system. disko orders
              # mounts by path prefix, so / is always up before anything nested
              # under it and the target root is writable by the time this runs.
              # Fires once per subvolume mount, hence the guard.
              postMountHook = ''
                if [ ! -f ${rootMountPoint}${keyDir}/${name}.key ]; then
                  install -D -m 0400 ${keyStagingDir}/${name}.key ${rootMountPoint}${keyDir}/${name}.key
                fi
              '';
            };
          };
        };
      };
    };
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
            # Second ESP, kept in sync by the bootloader (see the host's
            # `extraInstallCommands`). The array survives losing either drive,
            # but without this the bootloader lives only on nvme0 — lose that
            # one and the result is a perfectly intact RAID1 attached to a
            # machine that will not boot. Sized to match nvme0's ESP so the
            # two are interchangeable.
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot-fallback";
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

        # No recovery key: everything here is either re-downloadable from Valve
        # or covered by the compatdata backups, so losing the root array and
        # with it this volume's keyfile costs a re-download, not data.
        subvolumes = {
          # The library root. `common`, `downloading` and `shadercache` all stay
          # in this one subvolume deliberately: Steam installs a game by
          # renaming it out of `downloading` into `common`, and rename() across
          # a subvolume boundary is EXDEV. Splitting those would break installs.
          "/games" = {
            mountpoint = "/games";
            mountOptions = companionBtrfsOpts;
          };

          # Proton prefixes, and with them every local save for a game that does
          # not use Steam Cloud. Split out purely so it can be snapshotted and
          # backed up while the ~280G of re-downloadable game data around it is
          # not. Steam only ever writes prefixes here in place, so no rename
          # crosses this boundary; moving a game between libraries degrades to a
          # copy, which Steam already does across drives.
          "/compatdata" = {
            mountpoint = "/games/steamapps/compatdata";
            mountOptions = companionBtrfsOpts;
          };

          # The NixOS snapper module writes config files but never creates the
          # `.snapshots` subvolume they point at, so it is declared here — same
          # arrangement as /home/.snapshots on the root array.
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

        # This one has to survive losing the root array, or it is useless in the
        # one situation a third backup copy exists for. Its keyfile lives on
        # that array, so without a second keyslot a destroyed mirror would take
        # the local repository with it and leave only helium and rsync.net —
        # exactly when the fast local restore is worth the most. The recovery
        # key is printed once, during installation; store it with the borg
        # passphrase rather than on this machine.
        enrollRecovery = true;

        subvolumes = {
          # Deliberately not snapshotted, and there is no `.snapshots` subvolume
          # here on purpose. borg archives are already immutable and versioned,
          # so snapshots add no recoverable state — they would only pin every
          # segment `borg prune` deletes, turning a repository with bounded size
          # into one that only ever grows.
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

  # Opened in stage 2 from keyfiles on the encrypted root; see `initrdUnlock`
  # above. `nofail` here pairs with `nofail` in the mount options — a companion
  # that is missing, dead, or not yet formatted must never strand the boot.
  environment.etc.crypttab = lib.mkIf (companions != { }) {
    text = lib.concatMapStrings (
      name: "${name} ${companions.${name}}-part1 ${keyDir}/${name}.key luks,discard,nofail\n"
    ) (lib.attrNames companions);
  };
}
