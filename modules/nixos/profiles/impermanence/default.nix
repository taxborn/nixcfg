{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.myNixOS.profiles.impermanence;
  rootDevice = config.fileSystems."/".device;
  rootDeviceUnit = "${utils.escapeSystemdPath rootDevice}.device";
in
{
  options.myNixOS.profiles.impermanence = {
    enable = lib.mkEnableOption "btrfs root subvolume rollback impermanence";

    persistDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Directory where persistent state is bind-mounted from.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems.${cfg.persistDir}.neededForBoot = true;

    # Wipe the root subvolume on every boot by recreating it from the empty
    # /root-blank snapshot. The previous root is moved to /old_roots with a
    # timestamp so a forgotten persist path can still be recovered for 30
    # days. The rollback only fires when /root-blank exists, so a partial
    # disko run cannot brick the boot.
    boot.initrd.systemd.services.rollback = {
      description = "Rollback btrfs root subvolume to a pristine state";
      wantedBy = [ "initrd.target" ];
      requires = [ rootDeviceUnit ];
      after = [ rootDeviceUnit ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /btrfs_tmp
        mount -t btrfs -o subvol=/ ${rootDevice} /btrfs_tmp

        if [[ -e /btrfs_tmp/root-blank ]]; then
          if [[ -e /btrfs_tmp/root ]]; then
            mkdir -p /btrfs_tmp/old_roots
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
            mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
          fi

          delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
          }

          for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30 2>/dev/null); do
            delete_subvolume_recursively "$i"
          done

          btrfs subvolume snapshot /btrfs_tmp/root-blank /btrfs_tmp/root
        fi

        umount /btrfs_tmp
      '';
    };

    environment.persistence.${cfg.persistDir} = {
      hideMounts = true;

      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
      ]
      ++ lib.optionals config.myNixOS.services.tailscale.enable [
        "/var/lib/tailscale"
      ]
      ++ lib.optionals config.myNixOS.services.caddy.enable [
        "/var/lib/caddy"
      ]
      ++ lib.optionals config.myNixOS.services.fail2ban.enable [
        "/var/lib/fail2ban"
      ]
      ++ lib.optionals config.myNixOS.programs.podman.enable [
        "/var/lib/containers"
      ]
      ++ lib.optionals config.myNixOS.services.backups.client.enable [
        "/var/lib/borgmatic"
      ];

      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];

      users.taxborn = lib.mkIf config.myUsers.taxborn.enable {
        directories = [
          ".cache"
          ".config"
          ".local"
          ".ssh"
          "dev"
        ];
      };
    };
  };
}
