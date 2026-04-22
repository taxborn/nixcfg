{ config, lib, ... }:
let
  cfg = config.myNixOS.profiles.impermanence;

  baseDirectories = [
    "/etc/ssh"
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/var/lib/tailscale"
    "/var/lib/fail2ban"
    "/var/log"
    "/home/taxborn"
  ];
in
{
  options.myNixOS.profiles.impermanence = {
    enable = lib.mkEnableOption "impermanence via btrfs blank-snapshot rollback";
    extraDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific directories to persist beyond the fleet base set.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/persist".neededForBoot = true;

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = baseDirectories ++ cfg.extraDirectories;
      files = [ "/etc/machine-id" ];
    };

    # Roll back / to the blank snapshot on every boot.
    # The btrfs partition must carry label "nixos" (set in the disko config).
    boot.initrd.supportedFilesystems = [ "btrfs" ];
    boot.initrd.postDeviceCommands = lib.mkAfter ''
      mkdir /mnt
      mount -o subvol=/ /dev/disk/by-label/nixos /mnt
      btrfs subvolume list -o /mnt/root |
        cut -f9 -d' ' |
        while read subvolume; do
          echo "deleting /$subvolume subvolume..."
          btrfs subvolume delete "/mnt/$subvolume"
        done &&
      echo "deleting /root subvolume..." &&
      btrfs subvolume delete /mnt/root &&
      echo "restoring blank /root subvolume..." &&
      btrfs subvolume snapshot /mnt/blank /mnt/root
      umount /mnt
    '';
  };
}
